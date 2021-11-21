from pacstall.api.message import fancy, ask
from urllib.request import urlopen

def get_repolist():
    import toml
    return toml.load("/etc/pacstall/repolist.toml")

def get_packagelist(repo_url):
    f = urlopen(f'{repo_url}/packagelist')
    packagelist = f.read().decode('utf-8').split()
    return packagelist

def get_local():
    from glob import glob
    return [pkg.replace(".pacscript","") for pkg in glob("*.pacscript")]

def partial_match(package,package_list):
    match_list=[]
    # To do
    return match_list

def exact_match(package,package_list):
    return True if package in package_list else False

def print_results(package,result_list):
    print("To do")

def choose(package,repo_list):
    ask("To do","Y")
    return repo_list[0] # To do

def search(package, match=True, local=False):

    if local:
        if not match:
            match_list =  exact_match(package,package_list)
            print_results(match_list,package)
            return 0

        if match and ".pacscript" in package:
            from os.path import exists
            return package if exists(package) else -1
        
        packagelist = get_local()
        if match and exact_match(package,get_local()):
            return f"./{pgkname}.pacscript"
        
        return -1

    repo_list=get_repolist()
    repo = None

    if "@" in package:
        pkg_name, repo = package.split("@")

    if repo:
        try:
            repo_url = repo_list[repo]
        except:
            repo_url = repo

        packagelist = get_packagelist(repo_url)
        if pkg_name in packagelist:
            return f'{repo_url}/packages/{pkg_name}/{pkg_name}.pacscript'

        fancy("error", f"Package {pkg_name} not found in the repo provided")
        return -1
    
    if match:
        match_list = []
        for repo_url in repo_list.values():
            packagelist = get_packagelist(repo_url)
            if exact_match(pkg_name,packagelist):
                match_list.append(repo_url)
        
        if match_list:
            return choose(match_list)
        
        fancy("error", f"Package {pkg_name} not found")       
        return -1

    match_dict = {}

    for repo_url in repo_list.values():
        packagelist = get_packagelist(repo_url)

        for pkg_repo in partial_match():
            if pkg_repo in match_dict:
                match_dict[pkg_repo]+=[repo_url]
            match_dict[pkg_repo]=[repo_url]
    
    for pkg in match_dict:
        print_results(pkg_name, match_dict[pkg])
        return 0
            