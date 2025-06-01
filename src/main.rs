mod args;
mod cmds;
mod utilities;

use std::{fs::File, path::Path};

use args::{Arguments, Commands};
use clap::Parser;

use cmds::build_pkg::PackagePkg;
use libpacstall::{
    local::{pkglist::Search, repos::PacstallRepos},
    sys::shell::PacstallShell,
};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    match Arguments::parse().command {
        Commands::List => todo!(),
        Commands::Upgrade => todo!(),
        Commands::Repo(_) => todo!(),
        Commands::Info { package, key } => todo!(),
        Commands::Tree { package } => todo!(),
        Commands::Build { package, args } => {
            let mut shell = PacstallShell::new("RADIANCE").await?;
            shell.load_pacscript(package).await?;
            let handle = PackagePkg::new(shell)?;
            println!("{:#?}", handle.srcinfo);
        }
        Commands::Search { package } => {
            let repo_file = File::open(Path::new("/usr/share/pacstall/repo/pacstallrepo"))?;
            let repos = PacstallRepos::try_from(repo_file)?;
            let pkglist = Search::from(repos).into_pkglist().await?;
            for package_entry in pkglist.filter_pkg(&package).entries() {
                println!("{package_entry}");
            }
        }
        Commands::Remove { package } => todo!(),
        Commands::Install { package, args } => todo!(),
        Commands::Download { package } => todo!(),
        Commands::Mark { package, operation } => todo!(),
    }

    Ok(())
}
