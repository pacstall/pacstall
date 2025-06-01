use std::borrow::Cow;

use brush_core::{Shell, ShellValue, ShellVariable};
use libpacstall::{
    pkg::keys::{Arch, DistroClamp},
    srcinfo::{ArchDistro, PkgBase, SrcInfo},
    sys::shell::PacstallShell,
};

use strum::IntoEnumIterator;

pub struct PackagePkg {
    pub handle: PacstallShell,
    pub srcinfo: SrcInfo,
}

impl PackagePkg {
    pub fn new(handle: PacstallShell) -> anyhow::Result<Self> {
        let mut reference = handle.shell.clone();
        Ok(Self {
            handle,
            srcinfo: SrcInfo {
                pkgbase: PkgBase {
                    pkgbase: reference
                        .get_env_var("pkgbase")
                        .unwrap_or(&ShellVariable::new(
                            reference
                                .get_env_var("pkgname")
                                .expect("NO PKGNAME")
                                .value()
                                .clone(),
                        ))
                        .value()
                        .to_cow_str(&reference)
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
                    mask: Self::get_env_var_as_array(&reference, "mask"),
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
                    source: Self::collect_archdistro(&reference, "source"),
                    noextract: Self::get_env_var_as_array(&reference, "noextract"),
                    nosubmodules: Self::get_env_var_as_array(&reference, "nosubmodules"),
                    md5sums: Self::collect_archdistro(&reference, "md5sums"),
                    sha1sums: Self::collect_archdistro(&reference, "sha1sums"),
                    sha224sums: Self::collect_archdistro(&reference, "sha224sums"),
                    sha256sums: Self::collect_archdistro(&reference, "sha256sums"),
                    sha384sums: Self::collect_archdistro(&reference, "sha384sums"),
                    sha512sums: Self::collect_archdistro(&reference, "sha512sums"),
                    b2sums: Self::collect_archdistro(&reference, "b2sums"),
                    makedepends: Self::collect_archdistro(&reference, "makedepends"),
                    makeconflicts: Self::collect_archdistro(&reference, "makeconflicts"),
                },
                // TODO: Implement this.
                packages: vec![],
            },
        })
    }

    fn get_env_var_as_array(shell: &Shell, var: &str) -> Vec<String> {
        match shell.get_env_var(var) {
            Some(noextract) => match noextract.value() {
                ShellValue::String(string) => vec![string.to_string()],
                ShellValue::AssociativeArray(btree_map) => btree_map.values().cloned().collect(),
                ShellValue::IndexedArray(btree_map) => btree_map.values().cloned().collect(),
                ShellValue::Dynamic { .. } | ShellValue::Unset(_) => vec![],
            },
            None => vec![],
        }
    }

    /// Find all variants of a given `base_var`.
    ///
    /// In pacstall these are usually called "enhanced arrays".
    fn collect_archdistro(shell: &Shell, base_var: &str) -> Vec<(ArchDistro, String)> {
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
                    format!("{base_var}_{arch}_{distro}"),
                ));
            }
        }

        for possiblity in all_vars {
            if let Some(var) = shell.get_env_var(&possiblity.1) {
                match var.value() {
                    ShellValue::String(string) => {
                        out.push((possiblity.0, string.to_owned()));
                    }
                    ShellValue::AssociativeArray(btree_map) => {
                        for value in btree_map.values() {
                            out.push((possiblity.0.clone(), value.to_owned()));
                        }
                    }
                    ShellValue::IndexedArray(btree_map) => {
                        for value in btree_map.values() {
                            out.push((possiblity.0.clone(), value.to_owned()));
                        }
                    }
                    ShellValue::Dynamic { .. } | ShellValue::Unset(_) => {}
                }
            }
        }

        out
    }
}
