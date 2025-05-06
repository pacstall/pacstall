mod args;
mod cmds;
mod utilities;

use args::{Arguments, Commands};
use clap::Parser;
use cmds::search::Search;

fn main() -> anyhow::Result<()> {
    match Arguments::parse().command {
        Commands::List => fancy_message!(Error, "{}", "Working on it"),
        Commands::Upgrade => todo!(),
        Commands::Repo(_) => todo!(),
        Commands::Info { package, key } => todo!(),
        Commands::Tree { package } => todo!(),
        Commands::Build { package, args } => todo!(),
        Commands::Search { package } => {
            let pkglist =
                Search::from_repo_path("/usr/share/pacstall/repo/pacstallrepo")?.pkglist()?;
            println!("{}", pkglist.filter_pkg(&package));
        }
        Commands::Remove { package } => todo!(),
        Commands::Install { package, args } => todo!(),
        Commands::Download { package } => todo!(),
        Commands::Mark { package, operation } => todo!(),
    }

    Ok(())
}
