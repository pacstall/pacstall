use super::checks::Check;
use crate::cmds::build_pkg::PackagePkg;
use libpacstall::pkg::keys::{DistroClamp, PackageString};
use thiserror::Error;

pub(crate) struct Pkgdesc;

#[derive(Debug, Error)]
pub enum PkgdescError {
    #[error("Package: `{pkg}` has an empty `{var}`")]
    Empty { pkg: String, var: String },

    #[error("Package: `{pkg}` is missing `{var}`")]
    Missing { pkg: String, var: String },
}

impl Check for Pkgdesc {
    type Error = PkgdescError;

    fn name(&self) -> &'static str {
        "pkgdesc"
    }

    fn check(&self, pkgchild: &PackageString, handle: &PackagePkg, _system: &DistroClamp) -> Result<(), Self::Error> {
        let pkgdesc = if handle.srcinfo.is_child(pkgchild) {
            handle
                .srcinfo
                .packages
                .iter()
                .find(|package| package.pkgname == pkgchild)
                .map(|pkg| &pkg.pkgdesc)
        } else if handle.srcinfo.is_parent(pkgchild) {
            Some(&handle.srcinfo.pkgbase.pkgdesc)
        } else {
            panic!("pkgdesc not found in either pkgbase or child packages");
        };

        match pkgdesc {
            Some(yay) => {
                if yay.is_empty() {
                    Err(PkgdescError::Empty {
                        pkg: pkgchild.to_string(),
                        var: String::from("pkgdesc"),
                    })
                } else {
                    Ok(())
                }
            }
            None => Err(PkgdescError::Missing {
                pkg: pkgchild.to_string(),
                var: String::from("pkgdesc"),
            }),
        }
    }
}
