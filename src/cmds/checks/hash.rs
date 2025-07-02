use std::collections::HashSet;

use super::checks::Check;
use crate::{cmds::build_pkg::PackagePkg, fail_if};
use libpacstall::pkg::keys::{
    Arch, DistroClamp, DistroClampError, HashSumType, PackageKind, PackageString,
};
use thiserror::Error;

pub(crate) struct Hash;

#[derive(Debug, Error)]
pub enum HashError {
    #[error("Unexpected hash length for `{variant:?}`. Got `{got}`, expected `{expected}`")]
    UnexpectedLength {
        variant: HashSumType,
        got: usize,
        expected: usize,
    },
}

impl Check for Hash {
    type Error = HashError;

    fn name(&self) -> &'static str {
        "hash"
    }

    fn check(&self, _pkgchild: &PackageString, handle: &PackagePkg) -> Result<(), Self::Error> {
        let types = &handle.srcinfo.pkgbase;
        for (hash_type, list) in [
            (HashSumType::Md5, &types.md5sums),
            (HashSumType::Sha1, &types.sha1sums),
            (HashSumType::Sha224, &types.sha224sums),
            (HashSumType::Sha256, &types.sha256sums),
            (HashSumType::Sha384, &types.sha384sums),
            (HashSumType::Sha512, &types.sha512sums),
            (HashSumType::B2, &types.b2sums),
        ] {
            for (_, hash) in list {
                if hash.len() != hash_type.size() {
                    return Err(HashError::UnexpectedLength {
                        variant: hash_type,
                        got: hash.len(),
                        expected: hash_type.size(),
                    });
                }
            }
        }
        Ok(())
    }
}
