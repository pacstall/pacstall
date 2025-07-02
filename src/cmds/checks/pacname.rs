use std::collections::HashSet;

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
    TwoChars { pacname: String, text: String },

    #[error("{pacname}: `{text}` must start with an alphanumeric character")]
    Alphanumeric { pacname: String, text: String },

    #[error("{pacname}: `{text}` contains uppercase characters")]
    Uppercase { pacname: String, text: String },

    #[error(
        "{pacname}: `{text}` contains characters that are not lowercase, digits, minus, or periods"
    )]
    Alnum { pacname: String, text: String },
}

impl Check for Pacname {
    type Error = PacnameError;

    fn name(&self) -> &'static str {
        "pacname"
    }

    fn check(&self, pkgname: &PackageString, handle: &PackagePkg, _system: &DistroClamp) -> Result<(), Self::Error> {
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
                pacname: String::from("pacname"),
                text: pkgname.to_string(),
        });

        Ok(())
    }

    fn check_alphanumeric(pkgname: &str) -> Result<(), PacnameError> {
        fail_if!(['.', '-', '+'].contains(&pkgname.chars().next().unwrap()) => PacnameError::Alphanumeric {
            pacname: String::from("pacname"),
            text: pkgname.to_string()
        });

        Ok(())
    }

    fn check_lowercase(pkgname: &str) -> Result<(), PacnameError> {
        fail_if!(pkgname.to_ascii_lowercase() != *pkgname => PacnameError::Uppercase {
            pacname: String::from("pacname"),
            text: pkgname.to_string(),
        });

        Ok(())
    }

    fn check_alnum(pkgname: &str) -> Result<(), PacnameError> {
        let allowed: HashSet<char> = ('a'..='z').chain('0'..='9').chain(['-', '.']).collect();

        fail_if!(!pkgname.chars().all(|c| allowed.contains(&c)) => PacnameError::Alnum {
            pacname: String::from("pacname"),
            text: pkgname.to_string(),
        });

        Ok(())
    }
}
