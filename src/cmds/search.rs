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

#[derive(Debug)]
pub struct Package {
    pub name: String,
    pub repo: url::Url,
    pub pacscript: url::Url,
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

impl IntoIterator for PkgList {
    type Item = PkgBase;
    type IntoIter = std::vec::IntoIter<Self::Item>;

    fn into_iter(self) -> Self::IntoIter {
        self.contents.into_iter()
    }
}

impl Display for PkgList {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}",
            self.contents
                .iter()
                .map(|it| format!("{it}"))
                .collect::<Vec<_>>()
                .join("\n")
        )
    }
}

impl Display for PkgBase {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let mut it = self.packages.iter().peekable();
        while let Some(pkg) = it.next() {
            let pretty_url = match metalink(&pkg.repo) {
                Some(o) => o.pretty(),
                None => pkg.pacscript.to_string(),
            };
            // BUG: Does not print `pkg:pkgbase` ever.
            write!(
                f,
                "{} {} {}",
                if self.is_single() {
                    pkg.name.clone().green()
                } else {
                    format!("{}:{}", self.pkgbase, pkg.name).green()
                },
                "@".magenta(),
                pretty_url.cyan()
            )?;
            if it.peek().is_some() {
                writeln!(f)?;
            }
        }
        Ok(())
    }
}

impl PkgList {
    /// Search for package and flatten pkglist into non-recursive list (child packages will become
    /// "parent" packages).
    pub fn filter_pkg(self, search: &str) -> Self {
        PkgList {
            contents: self
                .contents
                .into_iter()
                .filter(|pkgbase| pkgbase.contains(search))
                .collect(),
        }
    }
}

impl PkgBase {
    pub fn is_single(&self) -> bool {
        self.packages.len() == 1 && self.pkgbase == self.packages[0].name
    }

    fn contains(&self, search: &str) -> bool {
        self.pkgbase.contains(search) || self.packages.iter().any(|pkg| pkg.name.contains(search))
    }

    fn lift(self) -> Vec<Self> {
        let mut pkgs = vec![];

        for pkg in self.packages {
            pkgs.push(PkgBase {
                pkgbase: pkg.name.clone(),
                packages: vec![pkg],
            });
        }

        pkgs
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
