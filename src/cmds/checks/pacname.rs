use std::collections::HashSet;

use super::checks::{Check, CheckError};
use crate::{cmds::build_pkg::PackagePkg, fail_if};
use thiserror::Error;

pub(crate) struct Pacname;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum PacnameError {
    #[error("Package does not contain `{0}`")]
    NoPacname(String),

    #[error("{pacname}: `{text}` must be at least two characters long")]
    TwoChars { pacname: String, text: String },

    #[error("{pacname}: `{text}` must start with an alphanumeric character")]
    Alphanumeric { pacname: String, text: String },

    #[error("{pacname}: `{text}` contains uppercase characters")]
    Uppercase { pacname: String, text: String },

    #[error("{pacname}: `{text}` contains characters that are not lowercase, digits, minus, or periods")]
    Alnum { pacname: String, text: String },
}

impl Check for Pacname {
    fn check(&self, pkgname: &str, handle: &PackagePkg) -> Result<(), CheckError> {
        let pkgname = &handle
            .srcinfo
            .packages
            .iter()
            .find(|srcinfo| srcinfo.pkgname == pkgname)
            .ok_or(PacnameError::NoPacname(pkgname.to_string()))?
            .pkgname;

        Self::check_len(pkgname)?;
        // We can unwrap here because of the check above.
        Self::check_alphanumeric(pkgname)?;
        Self::check_lowercase(pkgname)?;
        Self::check_alnum(pkgname)?;

        Ok(())
    }
}

impl Pacname {
    fn check_len(pkgname: &str) -> Result<(), CheckError> {
        fail_if!(pkgname.len() < 2 => CheckError::Pacname(PacnameError::TwoChars {
                pacname: String::from("pacname"),
                text: pkgname.to_string(),
        }));

        Ok(())
    }

    fn check_alphanumeric(pkgname: &str) -> Result<(), CheckError> {
        fail_if!(['.', '-', '+'].contains(&pkgname.chars().next().unwrap()) => CheckError::Pacname(PacnameError::Alphanumeric {
            pacname: String::from("pacname"),
            text: pkgname.to_string()
        }));

        Ok(())
    }

    fn check_lowercase(pkgname: &str) -> Result<(), CheckError> {
        fail_if!(pkgname.to_ascii_lowercase() != *pkgname => CheckError::Pacname(PacnameError::Uppercase {
            pacname: String::from("pacname"),
            text: pkgname.to_string(),
        }));

        Ok(())
    }

    fn check_alnum(pkgname: &str) -> Result<(), CheckError> {
        let allowed: HashSet<char> = ('a'..='z').chain('0'..='9').chain(['-', '.']).collect();

        fail_if!(pkgname.chars().all(|c| allowed.contains(&c)) => CheckError::Pacname(PacnameError::Alnum {
            pacname: String::from("pacname"),
            text: pkgname.to_string(),
        }));

        Ok(())
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn check_len_fails() {
        assert_eq!(Pacname::check_len("a").unwrap_err(), CheckError::Pacname(PacnameError::TwoChars { pacname: String::from("pacname"), text: String::from("a") }));
    }
}
