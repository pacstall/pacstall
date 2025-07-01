use libpacstall::pkg::keys::PackageString;
use thiserror::Error;

use crate::cmds::build_pkg::PackagePkg;

use super::{
    gives::{Gives, GivesError},
    pacname::{Pacname, PacnameError},
};

/// Simple wrapper for if then return error.
#[macro_export]
macro_rules! fail_if {
    ($expr:expr => $err:expr) => {
        if $expr {
            return Err($err);
        }
    };
}

/// Lints for pacstall.
pub trait Check {
    /// Check a particular key of a pacscript.
    fn check(&self, pkgchild: &PackageString, handle: &PackagePkg) -> Result<(), CheckError>;
}

pub struct Checks {
    checks: Vec<Box<dyn Check>>,
}

impl Default for Checks {
    fn default() -> Self {
        Self {
            checks: vec![Box::new(Pacname), Box::new(Gives)],
        }
    }
}

impl Checks {
    /// Run checks for pacstall.
    pub fn run(&self, pkgchild: &PackageString, handle: &PackagePkg) -> Result<(), CheckError> {
        for check in &self.checks {
            check.check(pkgchild, handle)?;
        }

        Ok(())
    }
}

#[derive(Debug, Error)]
pub enum CheckError {
    #[error(transparent)]
    Pacname(#[from] PacnameError),

    #[error(transparent)]
    Gives(#[from] GivesError),
}
