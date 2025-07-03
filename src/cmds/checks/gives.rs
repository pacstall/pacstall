use super::checks::Check;
use crate::{cmds::build_pkg::PackagePkg, fail_if};
use libpacstall::pkg::keys::{Arch, DistroClamp, PackageKind, PackageString};
use thiserror::Error;

pub(crate) struct Gives;

#[derive(Debug, Error)]
pub enum GivesError {
    #[error("Package does not contain `{0}`")]
    NoGives(&'static str),

    #[error("{pacname}: `{text}` must be at least two characters long")]
    TwoChars { pacname: &'static str, text: String },

    #[error("{pacname}: `{text}` must start with an alphanumeric character")]
    Alphanumeric { pacname: &'static str, text: String },

    #[error("{pacname}: `{text}` contains uppercase characters")]
    Uppercase { pacname: &'static str, text: String },

    #[error(
        "{pacname}: `{text}` contains characters that are not lowercase, digits, minus, or periods"
    )]
    Alnum { pacname: &'static str, text: String },
}

impl Check for Gives {
    type Error = GivesError;

    fn name(&self) -> &'static str {
        "gives"
    }

    fn check(
        &self,
        pkgchild: &PackageString,
        handle: &PackagePkg,
        system: &DistroClamp,
    ) -> Result<(), Self::Error> {
        let gives = &handle
            .srcinfo
            .packages
            .iter()
            .find(|srcinfo| srcinfo.pkgname == pkgchild)
            .map(|pkg| &pkg.gives);

        match gives {
            Some(gives_arches) if !gives_arches.is_empty() => {
                // Because gives could have possibly architecture dependent variables that
                // don't evaluate on another, we should only check the hosts arch.
                for check in [
                    Self::check_len,
                    Self::check_alphanumeric,
                    Self::check_lowercase,
                    Self::check_alnum,
                ] {
                    for arch in *gives_arches {
                        let (arch, evaled) = arch;
                        // If given arch is same as host (or missing) *and* the same for the
                        // distro/version.
                        if Arch::host() == *arch && system == arch {
                            check(evaled)?;
                        }
                    }
                }
            }
            _ => {
                // If this is a deb package, we have to have `gives`.
                fail_if!(pkgchild.split().1 == PackageKind::Deb => GivesError::NoGives("gives"));
            }
        }
        Ok(())
    }
}

impl Gives {
    fn check_len(gives: &str) -> Result<(), GivesError> {
        fail_if!(gives.len() < 2 => GivesError::TwoChars {
                pacname: "gives",
                text: gives.to_string(),
        });

        Ok(())
    }

    fn check_alphanumeric(gives: &str) -> Result<(), GivesError> {
        fail_if!(gives.starts_with(['.', '-', '+']) => GivesError::Alphanumeric {
            pacname: "gives",
            text: gives.to_string()
        });

        Ok(())
    }

    fn check_lowercase(gives: &str) -> Result<(), GivesError> {
        fail_if!(gives.chars().any(|c| c.is_ascii_uppercase()) => GivesError::Uppercase {
            pacname: "gives",
            text: gives.to_string(),
        });

        Ok(())
    }

    fn check_alnum(gives: &str) -> Result<(), GivesError> {
        let is_allowed = |c: char| matches!(c, 'a'..='z' | '0'..='9' | '-' | '.');

        fail_if!(gives.chars().any(|c| !is_allowed(c)) => GivesError::Alnum {
            pacname: "gives",
            text: gives.to_string(),
        });

        Ok(())
    }
}
