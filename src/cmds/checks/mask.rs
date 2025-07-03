use super::checks::Check;
use crate::cmds::build_pkg::PackagePkg;
use libpacstall::pkg::keys::{DistroClamp, PackageString};
use thiserror::Error;

pub(crate) struct Mask;

#[derive(Debug, Error)]
pub enum MaskError {
    #[error("{key}: index `{index}` cannot be empty")]
    Empty { key: &'static str, index: usize },
}

impl Check for Mask {
    type Error = MaskError;

    fn name(&self) -> &'static str {
        "mask"
    }

    fn check(
        &self,
        _pkgchild: &PackageString,
        handle: &PackagePkg,
        _system: &DistroClamp,
    ) -> Result<(), Self::Error> {
        for (index, mask) in handle.srcinfo.pkgbase.mask.iter().enumerate() {
            if mask.is_empty() {
                return Err(MaskError::Empty { key: "mask", index });
            }
        }

        Ok(())
    }
}
