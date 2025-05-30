use std::{
    fmt::Display,
    fs::{self, File},
    path::Path,
};

use anyhow::anyhow;
use colored::Colorize;
use libpacstall::local::{
    metalink::metalink,
    repos::{PacstallRepo, PacstallRepos},
};

pub struct Search {
    repos: PacstallRepos,
}

#[derive(Default)]
pub struct PkgList {
    pub contents: Vec<PkgBase>,
}

#[derive(Debug)]
pub struct PkgBase {
    pub pkgbase: String,
    pub packages: Vec<Package>,
}

#[derive(Debug, Clone)]
pub struct Package {
    pub name: String,
    pub repo: url::Url,
    pub pacscript: url::Url,
}

/// Used for filtering out package names into a pretty format.
///
/// This is the final output that users will see in `-S`.
#[derive(Debug)]
pub struct FilterPkg<'a> {
    needle: &'a str,
    pkgs: &'a [PkgBase],
}

// TODO: Sort output
impl Display for FilterPkg<'_> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        for pkgbase in self.pkgs {
            let pkg_pkgbase = pkgbase.pkgbase.as_str();
            // If pkgbase contains it
            if pkg_pkgbase.contains(self.needle) {
                for (idx, pkg) in pkgbase.packages.iter().enumerate() {
                    let pretty = match metalink(&pkg.repo) {
                        Some(o) => o.pretty(),
                        None => pkg.pacscript.to_string(),
                    };
                    if pkgbase.is_single() {
                        write!(f, "{} @ {}", pkg.name, pretty)?;
                    } else {
                        write!(f, "{pkg_pkgbase}:{} @ {}", pkg.name, pretty)?;
                    }
                    if idx != pkgbase.packages.iter().len() {
                        writeln!(f)?;
                    }
                }
            } else if pkgbase
                .packages
                .iter()
                .any(|pkg| pkg.name.contains(self.needle))
            {
                for (idx, pkg) in pkgbase.packages.iter().enumerate() {
                    if pkg.name.contains(self.needle) {
                        let pretty = match metalink(&pkg.repo) {
                            Some(o) => o.pretty(),
                            None => pkg.pacscript.to_string(),
                        };
                        if pkgbase.is_single() {
                            write!(f, "{} @ {}", pkg.name, pretty)?;
                        } else {
                            write!(f, "{pkg_pkgbase}:{} @ {}", pkg.name, pretty)?;
                        }
                        if idx != pkgbase.packages.iter().len() {
                            writeln!(f)?;
                        }
                    }
                }
            }
        }

        Ok(())
    }
}

impl From<PkgBase> for Package {
    fn from(value: PkgBase) -> Self {
        Self {
            name: value.packages[0].name.clone(),
            repo: value.packages[0].repo.clone(),
            pacscript: value.packages[0].pacscript.clone(),
        }
    }
}

impl IntoIterator for PkgBase {
    type Item = Package;
    type IntoIter = std::vec::IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        self.packages.into_iter()
    }
}

impl IntoIterator for &PkgBase {
    type Item = Package;
    type IntoIter = std::vec::IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        self.packages.clone().into_iter()
    }
}

impl IntoIterator for PkgList {
    type Item = PkgBase;
    type IntoIter = std::vec::IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        self.contents.into_iter()
    }
}

impl PkgList {
    /// Search for package and flatten pkglist into non-recursive list (child packages will become
    /// "parent" packages).
    pub fn filter_pkg<'a>(&'a self, search: &'a str) -> FilterPkg<'a> {
        FilterPkg {
            needle: search,
            pkgs: self.contents.as_slice(),
        }
    }
}

impl PkgBase {
    pub fn is_single(&self) -> bool {
        self.packages.len() == 1 && self.pkgbase == self.packages[0].name
    }

    pub fn flatten_pkgbase(&self) -> &[Package] {
        &self.packages
    }

    fn contains(&self, search: &str) -> bool {
        self.pkgbase.contains(search) || self.packages.iter().any(|pkg| pkg.name.contains(search))
    }
}

impl Search {
    pub fn new(repos: PacstallRepos) -> Self {
        Self { repos }
    }

    pub fn from_repo_path<S: AsRef<Path>>(path: S) -> anyhow::Result<Self> {
        Ok(Self {
            repos: PacstallRepos::try_from(File::open(path)?)?,
        })
    }

    pub fn pkglist(&self) -> anyhow::Result<PkgList> {
        let mut pkglist = PkgList::default();

        for entry in self.repos.clone() {
            let url = entry.url();
            let list = if let Ok(path) = url.to_file_path() {
                let list_path = path.join("packagelist");
                fs::read_to_string(list_path)?
            } else {
                let url = format!("{url}/packagelist");
                reqwest::blocking::get(&url)?.text()?
            };
            for pkg_entry in list.trim().lines() {
                let parts: Vec<_> = pkg_entry.split(':').collect();

                match parts.as_slice() {
                    [pkgbase] => {
                        pkglist.contents.push(PkgBase {
                            pkgbase: (*pkgbase).to_string(),
                            packages: vec![Package {
                                name: (*pkgbase).to_string(),
                                repo: url.clone(),
                                pacscript: format!("{url}/packages/{pkgbase}/{pkgbase}.pacscript")
                                    .parse()?,
                            }],
                        });
                    }
                    [pkg, "pkgbase"] => {
                        pkglist.contents.push(PkgBase {
                            pkgbase: (*pkg).to_string(),
                            packages: vec![],
                        });
                    }
                    [pkg, child] => {
                        let parent = pkglist
                            .contents
                            .iter_mut()
                            .find(|p| p.pkgbase == *pkg)
                            .ok_or_else(|| anyhow!("Missing parent pkgbase for: {}", pkg))?;

                        parent.packages.push(Package {
                            name: (*child).to_string(),
                            repo: url.clone(),
                            pacscript: format!("{url}/packages/{pkg}/{pkg}.pacscript").parse()?,
                        });
                    }
                    _ => return Err(anyhow!("Invalid line in packagelist: {pkg_entry}")),
                }
            }
        }

        Ok(pkglist)
    }
}

impl IntoIterator for Search {
    type Item = PacstallRepo;
    type IntoIter = std::vec::IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        self.repos.into_iter()
    }
}
