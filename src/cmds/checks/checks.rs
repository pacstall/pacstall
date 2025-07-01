use thiserror::Error;

use crate::cmds::build_pkg::PackagePkg;

use super::pacname::{Pacname, PacnameError};

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
    /// Check functionality.
    fn check(&self, pkgname: &str, handle: &PackagePkg) -> Result<(), CheckError>;
}

pub struct Checks {
    checks: Vec<Box<dyn Check>>,
}

impl Default for Checks {
    fn default() -> Self {
        Self {
            checks: vec![Box::new(Pacname)],
        }
    }
}

impl Checks {
    pub fn run(&self, pkgname: &str, handle: &PackagePkg) -> Result<(), CheckError> {
        for check in &self.checks {
            check.check(pkgname, handle)?;
        }

        Ok(())
    }
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum CheckError {
    #[error(transparent)]
    Pacname(#[from] PacnameError),
}
