use std::collections::HashMap;

use super::checks::Check;
use crate::{cmds::build_pkg::PackagePkg, fail_if};
use libpacstall::{
    pkg::keys::{Arch, DistroClamp, DistroClampError, PackageKind, PackageString},
    srcinfo::ArchDistro,
};
use thiserror::Error;

pub(crate) struct DebSource;

#[derive(Debug, Error)]
pub enum DebSourceError {
    #[error("Only deb files can be provided in `{0}`")]
    NonDeb(String),

    #[error("Deb files can only be provided as a singular `{0}`")]
    Singular(String),

    #[error(transparent)]
    DistroClampError(#[from] DistroClampError),
}

impl Check for DebSource {
    type Error = DebSourceError;

    fn name(&self) -> &'static str {
        "deb source"
    }

    fn check(&self, pkgchild: &PackageString, handle: &PackagePkg, system: &DistroClamp) -> Result<(), Self::Error> {
        // It's not our time yet...
        if pkgchild.split().1 != PackageKind::Deb {
            return Ok(());
        }

        let source = &handle.srcinfo.pkgbase.source;

        let mut compatible_sources: HashMap<ArchDistro, Vec<String>> = HashMap::new();

        for (arch, string) in source {
            if Arch::host() == *arch && system == arch {
                compatible_sources
                    .entry(arch.clone())
                    .or_default()
                    .push(string.to_string());
            }
        }

        for (arch, entries) in compatible_sources {
            fail_if!(entries.len() != 1 => DebSourceError::Singular(if arch.is_enhanced() {
                format!("source_{arch}")
            } else {
                String::from("source")
            }));

            // This is safe because we did the check above.
            fail_if!(!entries[0].ends_with(".deb") => DebSourceError::NonDeb(if arch.is_enhanced() {
                format!("source_{arch}")
            } else {
                String::from("source")
            }));
        }

        Ok(())
    }
}
