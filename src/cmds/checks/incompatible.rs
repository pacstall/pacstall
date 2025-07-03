use std::fmt::Display;

use super::checks::Check;
use crate::cmds::build_pkg::PackagePkg;
use libpacstall::pkg::keys::{DistroClamp, PackageString};
use thiserror::Error;

pub(crate) struct Incompatible;

/// This is a lean distroclamp used only for errors so that it doesn't contain a copy of
/// `/etc/os-release` and other bigboy items.
#[derive(Debug, PartialEq, Eq, Clone, Hash)]
pub struct LeanClamp {
    pub distro: String,
    pub version: String,
}

impl From<DistroClamp> for LeanClamp {
    fn from(value: DistroClamp) -> Self {
        Self {
            distro: value.distro().to_string(),
            version: value.version().to_string(),
        }
    }
}

impl Display for LeanClamp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}:{}", self.distro, self.version)
    }
}

#[derive(Debug, Error)]
pub enum IncompatibleError {
    #[error("Key `{clamp}` found in both `{first}` and `{second}`")]
    Duplicate {
        clamp: LeanClamp,
        first: &'static str,
        second: &'static str,
    },
}

impl Check for Incompatible {
    type Error = IncompatibleError;

    fn name(&self) -> &'static str {
        "incompatible/compatible"
    }

    fn check(
        &self,
        _pkgchild: &PackageString,
        handle: &PackagePkg,
        _system: &DistroClamp,
    ) -> Result<(), Self::Error> {
        let (incompatible, compatible) = (
            &handle.srcinfo.pkgbase.incompatible,
            &handle.srcinfo.pkgbase.compatible,
        );

        if let Some(failed_clamp) = Self::duplicates(incompatible, compatible) {
            return Err(IncompatibleError::Duplicate {
                clamp: failed_clamp.into(),
                first: "compatible",
                second: "incompatible",
            });
        }

        Ok(())
    }
}

impl Incompatible {
    fn duplicates(incompatible: &[DistroClamp], compatible: &[DistroClamp]) -> Option<DistroClamp> {
        for incompat in incompatible {
            for compat in compatible {
                if compat.lit_eq(incompat) {
                    return Some(compat.clone());
                }
            }
        }
        None
    }
}

#[cfg(test)]
mod test {
    use std::str::FromStr;

    use libpacstall::pkg::keys::DistroClamp;

    use crate::cmds::checks::incompatible::Incompatible;

    #[test]
    fn test_simple_duplicate() {
        let incompatible = [DistroClamp::from_str("ubuntu:18.04").unwrap()];
        let compatible = [DistroClamp::from_str("ubuntu:18.04").unwrap()];

        assert!(Incompatible::duplicates(&incompatible, &compatible).is_some());
    }

    #[test]
    fn globs_dont_matter() {
        let incompatible = [DistroClamp::from_str("*:18.04").unwrap()];
        let compatible = [DistroClamp::from_str("ubuntu:18.04").unwrap()];

        assert!(Incompatible::duplicates(&incompatible, &compatible).is_none());
    }
}
