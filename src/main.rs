mod args;
mod cmds;
mod utilities;

use std::{fs::File, path::Path};

use args::{Arguments, Commands};
use clap::Parser;
use cmds::search::Search;
use libpacstall::local::repos::PacstallRepos;

fn main() -> anyhow::Result<()> {
    match Arguments::parse().command {
        Commands::List => fancy_message!(Error, "{}", "Working on it"),
        Commands::Upgrade => todo!(),
        Commands::Repo(_) => todo!(),
        Commands::Info { package, key } => todo!(),
        Commands::Tree { package } => todo!(),
        Commands::Build { package, args } => todo!(),
        Commands::Search { package } => {
            let file = File::open(Path::new("/usr/share/pacstall/repo/pacstallrepo"))?;
            let repos = match PacstallRepos::try_from(file) {
                Ok(o) => o,
                Err(e) => {
                    eprintln!("{e}");
                    std::process::exit(1);
                }
            };
            let search = Search::new(repos);
            let pkglist = search.pkglist()?;
            println!("{:#?}", pkglist);
        }
        Commands::Remove { package } => todo!(),
        Commands::Install { package, args } => todo!(),
        Commands::Download { package } => todo!(),
        Commands::Mark { package, operation } => todo!(),
    }

    Ok(())
}
