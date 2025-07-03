use super::checks::Check;
use crate::{cmds::build_pkg::PackagePkg, fail_if};
use libpacstall::pkg::keys::{DistroClamp, PackageString};
use thiserror::Error;

pub(crate) struct Pacname;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum PacnameError {
    #[error("Package does not contain `{0}`")]
    NoPacname(String),

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

impl Check for Pacname {
    type Error = PacnameError;

    fn name(&self) -> &'static str {
        "pacname"
    }

    fn check(
        &self,
        pkgname: &PackageString,
        handle: &PackagePkg,
        _system: &DistroClamp,
    ) -> Result<(), Self::Error> {
        let pkgname = if handle.srcinfo.is_child(pkgname) {
            &handle
                .srcinfo
                .packages
                .iter()
                .find(|srcinfo| srcinfo.pkgname == pkgname)
                .ok_or(PacnameError::NoPacname(pkgname.to_string()))?
                .pkgname
        } else if handle.srcinfo.is_parent(pkgname) {
            &handle.srcinfo.pkgbase.pkgbase
        } else {
            panic!("Fatal error, could not find `{pkgname}` in children packages or pkgbase");
        };

        for check in [
            Self::check_len,
            Self::check_alphanumeric,
            Self::check_lowercase,
            Self::check_alnum,
        ] {
            check(pkgname)?;
        }

        Ok(())
    }
}

impl Pacname {
    fn check_len(pkgname: &str) -> Result<(), PacnameError> {
        fail_if!(pkgname.len() < 2 => PacnameError::TwoChars {
                pacname: "pacname",
                text: pkgname.to_string(),
        });

        Ok(())
    }

    fn check_alphanumeric(pkgname: &str) -> Result<(), PacnameError> {
        fail_if!(pkgname.starts_with(['.', '-', '+']) => PacnameError::Alphanumeric {
            pacname: "pacname",
            text: pkgname.to_string()
        });

        Ok(())
    }

    fn check_lowercase(pkgname: &str) -> Result<(), PacnameError> {
        fail_if!(pkgname.chars().any(|c| c.is_ascii_uppercase()) => PacnameError::Uppercase {
            pacname: "pacname",
            text: pkgname.to_string(),
        });

        Ok(())
    }

    fn check_alnum(pkgname: &str) -> Result<(), PacnameError> {
        let is_allowed = |c: char| matches!(c, 'a'..='z' | '0'..='9' | '-' | '.');

        fail_if!(pkgname.chars().any(|c| !is_allowed(c)) => PacnameError::Alnum {
            pacname: "pacname",
            text: pkgname.to_string(),
        });

        Ok(())
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    #[should_panic]
    fn length_too_small() {
        Pacname::check_len("f").unwrap();
    }

    #[test]
    fn lengh_works() {
        assert!(Pacname::check_len("foobar").is_ok());
    }

    #[test]
    #[should_panic]
    fn has_uppercase() {
        Pacname::check_lowercase("neofetcH").unwrap();
    }

    #[test]
    #[should_panic]
    fn alnum() {
        Pacname::check_alnum("foo%bar").unwrap();
    }
}
