use std::fs;

use anyhow::anyhow;
use libpacstall::local::repos::{PacstallRepo, PacstallRepos};

pub type PkgList = Vec<PkgBase>;

pub struct Search {
    repos: PacstallRepos,
}

#[derive(Debug)]
pub struct PkgBase {
    pkgbase: String,
    packages: Vec<Package>,
}

#[derive(Debug)]
pub struct Package {
    name: String,
    pacscript: url::Url,
}

impl PkgBase {
    pub fn is_single(&self) -> bool {
        self.packages.len() == 1 && self.pkgbase == self.packages[0].name
    }
}

impl Search {
    pub fn new(repos: PacstallRepos) -> Self {
        Self { repos }
    }

    pub fn pkglist(&self) -> anyhow::Result<PkgList> {
        let mut pkglist = vec![];

        for entry in self.repos.clone() {
            let list = if entry.url().as_str().starts_with("file://") {
                fs::read_to_string(match entry.url().to_file_path() {
                    Ok(o) => format!("{}/packagelist", o.to_string_lossy()),
                    Err(()) => return Err(anyhow!("Could not convert to pathbuf")),
                })?
            } else {
                reqwest::blocking::get(format!("{}/packagelist", entry.url().to_owned()))?.text()?
            };
            for pkg_entry in list.lines() {
                if !pkg_entry.contains(':') {
                    pkglist.push(PkgBase {
                        pkgbase: pkg_entry.to_string(),
                        packages: vec![Package {
                            name: pkg_entry.to_string(),
                            pacscript: entry
                                .url()
                                .clone()
                                .join(&format!("packages/{pkg_entry}/{pkg_entry}.pacscript"))?,
                        }],
                    });
                } else {
                    match pkg_entry.split(':').collect::<Vec<_>>()[..] {
                        [pkg, "pkgbase"] => {
                            pkglist.push(PkgBase {
                                pkgbase: pkg.to_string(),
                                packages: vec![],
                            });
                        }
                        [pkg, child] => {
                            pkglist
                                .iter_mut()
                                .find(|parent| parent.pkgbase == pkg)
                                .unwrap_or_else(|| panic!("Could not find {pkg}:pkgbase"))
                                .packages
                                .push(Package {
                                    name: child.to_string(),
                                    pacscript: entry
                                        .url()
                                        .clone()
                                        .join(&format!("packages/{pkg}/{pkg}.pacscript"))?,
                                });
                        }
                        _ => return Err(anyhow!("Invalid syntax for packagelist: {}", pkg_entry)),
                    }
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
