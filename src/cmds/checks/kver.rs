use super::checks::Check;
use crate::cmds::build_pkg::PackagePkg;
use libpacstall::pkg::keys::{DistroClamp, PackageString};
use thiserror::Error;

pub(crate) struct Kver;

#[derive(Debug, Error)]
pub enum KverError {
    #[error("{key}: `{val}` must be prefixed with a constraint (<=|>=|=|<|>)")]
    Constraint { key: &'static str, val: String },
}

impl Check for Kver {
    type Error = KverError;

    fn name(&self) -> &'static str {
        "kver"
    }

    fn check(
        &self,
        _pkgchild: &PackageString,
        handle: &PackagePkg,
        _system: &DistroClamp,
    ) -> Result<(), Self::Error> {
        if let Some(kver) = &handle.srcinfo.pkgbase.kver {
            if !Self::has_constraint_prefix(kver) {
                return Err(KverError::Constraint {
                    key: "kver",
                    val: kver.to_owned(),
                });
            }
        }

        Ok(())
    }
}

impl Kver {
    fn has_constraint_prefix(s: &str) -> bool {
        s.starts_with('<')
            || s.starts_with('>')
            || s.starts_with("<=")
            || s.starts_with(">=")
            || s.starts_with('=')
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn constraint_exists_double() {
        assert!(Kver::has_constraint_prefix(">=6.14.0"));
    }

    #[test]
    fn constraint_exists_single() {
        assert!(Kver::has_constraint_prefix("<1.0.0"));
    }

    #[test]
    fn has_no_prefix() {
        assert!(!Kver::has_constraint_prefix("6.15.0"));
    }

    #[test]
    fn prefix_at_end() {
        assert!(!Kver::has_constraint_prefix("6.15.0="));
    }
}
