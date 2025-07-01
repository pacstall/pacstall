use std::{borrow::Cow, path::PathBuf};

use brush_core::{Shell, ShellValue, ShellVariable};
use libpacstall::{
    pkg::keys::{Arch, DistroClamp},
    srcinfo::{ArchDistro, PkgBase, PkgInfo, SrcInfo},
    sys::shell::PacstallShell,
};

use strum::IntoEnumIterator;
use thiserror::Error;

use crate::{args::PkgArgs, fancy_message};

use super::checks::checks::{CheckError, Checks};

pub struct PackagePkg {
    pub handle: PacstallShell,
    pub srcinfo: SrcInfo,
}

#[derive(Debug, Error)]
pub enum SourceError {
    #[error("missing function: `{name}`")]
    MissingPackageFunction {
        name: String,
        #[source]
        source: brush_core::Error,
    },

    #[error(transparent)]
    Brush(#[from] brush_core::Error),

    #[error(transparent)]
    Parse(#[from] std::num::ParseIntError),

    #[error(transparent)]
    DistroClamp(#[from] libpacstall::pkg::keys::DistroClampError),

    #[error(transparent)]
    MaintainerParse(#[from] libpacstall::pkg::keys::MaintainerParseError),
}

#[derive(Debug, Error)]
pub enum BuildError {
    #[error(transparent)]
    CheckError(#[from] CheckError),
}

impl PackagePkg {
    /// Load in all pacscript variables into [`Self::srcinfo`].
    pub async fn new(handle: PacstallShell) -> Result<Self, SourceError> {
        let reference = handle.shell.clone();
        Ok(Self {
            handle,
            srcinfo: SrcInfo {
                pkgbase: PkgBase {
                    pkgbase: reference
                        .get_env_str("pkgbase")
                        .unwrap_or(
                            reference
                                .get_env_var("pkgname")
                                .expect("NO PKGNAME")
                                .value()
                                .to_cow_str(&reference),
                        )
                        .to_string(),
                    pkgver: reference
                        .get_env_str("pkgver")
                        .expect("NO PKGVER")
                        .to_string(),
                    pkgrel: reference
                        .get_env_str("pkgrel")
                        .unwrap_or(Cow::Borrowed("1"))
                        .parse()?,
                    epoch: reference
                        .get_env_str("epoch")
                        .unwrap_or(Cow::Borrowed("0"))
                        .parse()?,
                    mask: Self::get_env_var_as_array(&reference, "mask", |s| s.to_string()),
                    compatible: match reference.get_env_var("compatible") {
                        Some(compatible) => match compatible.value() {
                            ShellValue::String(string) => vec![string.parse()?],
                            ShellValue::AssociativeArray(btree_map) => btree_map
                                .values()
                                .cloned()
                                .filter_map(|v| v.parse().ok())
                                .collect(),
                            ShellValue::IndexedArray(btree_map) => btree_map
                                .values()
                                .cloned()
                                .filter_map(|v| v.parse().ok())
                                .collect(),
                            ShellValue::Dynamic { .. } | ShellValue::Unset(_) => vec![],
                        },
                        None => vec![],
                    },
                    incompatible: match reference.get_env_var("incompatible") {
                        Some(incompatible) => match incompatible.value() {
                            ShellValue::String(string) => vec![string.parse()?],
                            ShellValue::AssociativeArray(btree_map) => btree_map
                                .values()
                                .cloned()
                                .filter_map(|v| v.parse().ok())
                                .collect(),
                            ShellValue::IndexedArray(btree_map) => btree_map
                                .values()
                                .cloned()
                                .filter_map(|v| v.parse().ok())
                                .collect(),
                            ShellValue::Dynamic { .. } | ShellValue::Unset(_) => vec![],
                        },
                        None => vec![],
                    },
                    maintainer: match reference.get_env_var("maintainer") {
                        Some(maintainers) => match maintainers.value() {
                            ShellValue::String(string) => vec![string.parse()?],
                            ShellValue::AssociativeArray(btree_map) => btree_map
                                .values()
                                .cloned()
                                .filter_map(|v| v.parse().ok())
                                .collect(),
                            ShellValue::IndexedArray(btree_map) => btree_map
                                .values()
                                .cloned()
                                .filter_map(|v| v.parse().ok())
                                .collect(),
                            ShellValue::Dynamic { .. } | ShellValue::Unset(_) => vec![],
                        },
                        None => vec![],
                    },
                    source: Self::collect_archdistro(&reference, "source", |s| s.to_string()),
                    noextract: Self::get_env_var_as_array(&reference, "noextract", |s| {
                        s.to_string()
                    }),
                    nosubmodules: Self::get_env_var_as_array(&reference, "nosubmodules", |s| {
                        s.to_string()
                    }),
                    md5sums: Self::collect_archdistro(&reference, "md5sums", |s| s.to_string()),
                    sha1sums: Self::collect_archdistro(&reference, "sha1sums", |s| s.to_string()),
                    sha224sums: Self::collect_archdistro(&reference, "sha224sums", |s| {
                        s.to_string()
                    }),
                    sha256sums: Self::collect_archdistro(&reference, "sha256sums", |s| {
                        s.to_string()
                    }),
                    sha384sums: Self::collect_archdistro(&reference, "sha384sums", |s| {
                        s.to_string()
                    }),
                    sha512sums: Self::collect_archdistro(&reference, "sha512sums", |s| {
                        s.to_string()
                    }),
                    b2sums: Self::collect_archdistro(&reference, "b2sums", |s| s.to_string()),
                    makedepends: Self::collect_archdistro(&reference, "makedepends", |s| {
                        s.to_string()
                    }),
                    makeconflicts: Self::collect_archdistro(&reference, "makeconflicts", |s| {
                        s.to_string()
                    }),
                },
                packages: {
                    let packages =
                        Self::get_env_var_as_array(&reference, "pkgname", |s| s.to_string());
                    if packages.len() > 1 {
                        // So basically, we will have "global variables", so having a global
                        // "depends" but can be overridden on a per-package basis.
                        let mut child_packages: Vec<PkgInfo> = vec![];

                        for child in packages {
                            // Firstly, we want a fresh environment for every child, so we clone
                            // reference.
                            let mut child_reference = reference.clone();
                            // So now we have to extract variables from `package_${pkgname}`.
                            // This follows generally `srcinfo.extr_fnvar`.
                            Self::extract_fn_vars(
                                &mut child_reference,
                                &format!("package_{child}"),
                            )
                            .await?;
                            // Set default package info, we will overwrite some after.
                            let pkginfo = Self::default_pkginfo(&child_reference, child);

                            child_packages.push(pkginfo);
                        }

                        child_packages
                    } else {
                        // Single package.
                        vec![Self::default_pkginfo(&reference, packages[0].clone())]
                    }
                },
            },
        })
    }

    fn default_pkginfo<S: Into<String>>(reference: &Shell, pkgname: S) -> PkgInfo {
        PkgInfo {
            pkgname: pkgname.into(),
            pkgdesc: Self::get_env_var_as_string(reference, "pkgdesc"),
            url: Self::get_env_var_as_string(reference, "url"),
            priority: Self::get_env_var_as_string(reference, "priority").into(),
            arch: match reference.get_env_var("arch") {
                Some(maintainers) => match maintainers.value() {
                    ShellValue::String(string) => vec![string.to_owned().into()],
                    ShellValue::AssociativeArray(btree_map) => {
                        btree_map.values().cloned().map(|v| v.into()).collect()
                    }
                    ShellValue::IndexedArray(btree_map) => {
                        btree_map.values().cloned().map(|v| v.into()).collect()
                    }
                    ShellValue::Dynamic { .. } | ShellValue::Unset(_) => vec![],
                },
                None => vec![],
            },
            license: Self::get_env_var_as_array(reference, "license", |s| s.to_string()),
            gives: Self::collect_archdistro(reference, "gives", |s| s.to_string()),
            depends: Self::collect_archdistro(reference, "depends", |s| s.to_string()),
            checkdepends: Self::collect_archdistro(reference, "checkdepends", |s| s.to_string()),
            optdepends: Self::collect_archdistro(reference, "optdepends", |s| s.to_string()),
            checkconflicts: Self::collect_archdistro(reference, "checkconflicts", |s| {
                s.to_string()
            }),
            conflicts: Self::collect_archdistro(reference, "conflicts", |s| s.to_string()),
            provides: Self::collect_archdistro(reference, "provides", |s| s.to_string()),
            breaks: Self::collect_archdistro(reference, "breaks", |s| s.to_string()),
            replaces: Self::collect_archdistro(reference, "replaces", |s| s.to_string()),
            enhances: Self::collect_archdistro(reference, "enhances", |s| s.to_string()),
            recommends: Self::collect_archdistro(reference, "recommends", |s| s.to_string()),
            suggests: Self::collect_archdistro(reference, "suggests", |s| s.to_string()),
            backup: Self::get_env_var_as_array(reference, "backup", |s| s.to_string()),
            repology: Self::get_env_var_as_array(reference, "repology", |s| s.to_string()),
        }
    }

    fn get_env_var_as_array<I, F>(shell: &Shell, var: &str, mapper: F) -> Vec<I>
    where
        F: Fn(&str) -> I,
    {
        match shell.get_env_var(var) {
            Some(noextract) => match noextract.value() {
                ShellValue::String(string) => vec![mapper(string)],
                ShellValue::AssociativeArray(btree_map) => {
                    btree_map.values().map(|v| mapper(v)).collect()
                }
                ShellValue::IndexedArray(btree_map) => {
                    btree_map.values().map(|v| mapper(v)).collect()
                }
                ShellValue::Dynamic { .. } | ShellValue::Unset(_) => vec![],
            },
            None => vec![],
        }
    }

    fn get_env_var_as_string(shell: &Shell, var: &str) -> String {
        match shell.get_env_str(var) {
            Some(string) => string.to_string(),
            None => String::new(),
        }
    }

    /// Basically we set `PATH=""` and run the function lol. Could this be better? Nah, it's bash,
    /// fuck bash.
    async fn extract_fn_vars(shell: &mut Shell, func: &str) -> Result<(), SourceError> {
        let path = shell
            .get_env_var("PATH")
            .expect("Bitchass PATH don't exist")
            .clone();

        shell.set_env_global(
            "PATH",
            ShellVariable::new(ShellValue::String(String::new())),
        )?;

        let mut params = shell.default_exec_params();

        params
            .open_files
            .set(brush_core::OpenFiles::STDERR_FD, brush_core::OpenFile::Null);

        match shell
            .invoke_function(func, std::iter::once("foo"), &params)
            .await
        {
            Ok(_) => {}
            Err(e) => {
                return Err(SourceError::MissingPackageFunction {
                    name: func.to_string(),
                    source: e,
                });
            }
        }

        shell.set_env_global("PATH", path)?;

        Ok(())
    }

    /// Find all variants of a given `base_var`.
    ///
    /// In pacstall these are usually called "enhanced arrays".
    fn collect_archdistro<I, F>(shell: &Shell, base_var: &str, mapper: F) -> Vec<(ArchDistro, I)>
    where
        F: Fn(&str) -> I,
    {
        let distro_info = match DistroClamp::system() {
            Ok(o) => o.info.unwrap_or(vec![]),
            Err(_) => vec![],
        };

        let mut out = vec![];

        // Time to find *all* possible variants baby.
        // Here, the vec is: (ArchDistro, possible array name).
        let mut all_vars: Vec<(ArchDistro, String)> = vec![(
            ArchDistro {
                arch: None,
                distro: None,
            },
            base_var.to_string(),
        )];

        let arches: Vec<_> = Arch::iter().collect();
        let mut distros: Vec<String> = vec![];

        for dist in &distro_info {
            distros.push(dist.codename.clone());
            if let Some(version) = &dist.version {
                distros.push(version.clone());
            }
        }

        for arch in &arches {
            all_vars.push((
                ArchDistro {
                    arch: Some(arch.clone()),
                    distro: None,
                },
                format!("{base_var}_{arch}"),
            ));
        }

        for distro in &distros {
            all_vars.push((
                ArchDistro {
                    arch: None,
                    distro: Some(distro.clone()),
                },
                format!("{base_var}_{distro}"),
            ));
        }

        for arch in &arches {
            for distro in &distros {
                all_vars.push((
                    ArchDistro {
                        arch: Some(arch.clone()),
                        distro: Some(distro.clone()),
                    },
                    format!("{base_var}_{distro}_{arch}"),
                ));
            }
        }

        for possiblity in all_vars {
            if let Some(var) = shell.get_env_var(&possiblity.1) {
                match var.value() {
                    ShellValue::String(string) => {
                        out.push((possiblity.0, mapper(string)));
                    }
                    ShellValue::AssociativeArray(btree_map) => {
                        for value in btree_map.values() {
                            out.push((possiblity.0.clone(), mapper(value)));
                        }
                    }
                    ShellValue::IndexedArray(btree_map) => {
                        for value in btree_map.values() {
                            out.push((possiblity.0.clone(), mapper(value)));
                        }
                    }
                    ShellValue::Dynamic { .. } | ShellValue::Unset(_) => {}
                }
            }
        }

        out
    }

    /// Builds a package into a deb.
    ///
    /// # Errors
    /// Errors if any part of the build fails, else return the paths to the debs.
    pub async fn build(&mut self, args: PkgArgs) -> Result<Vec<PathBuf>, BuildError> {
        let pkg = if self.srcinfo.len() > 1 {
            unimplemented!("Pkgchildren");
        } else {
            vec![self.srcinfo.packages[0].pkgname.clone()]
        };

        self.package(&pkg, args).await
    }

    async fn package(
        &mut self,
        pkgs: &[String],
        args: PkgArgs,
    ) -> Result<Vec<PathBuf>, BuildError> {
        for pkg in pkgs {
            if self.handle.shell.get_env_str("external_connection") == Some(Cow::Borrowed("true")) {
                fancy_message!(
                    Warn,
                    "This package will connect to the internet during its build process."
                );
            }

            // Do checks here.
            let checks = Checks::default();

            checks.run(pkg, self)?;
        }

        Ok(vec![PathBuf::default()])
    }
}
