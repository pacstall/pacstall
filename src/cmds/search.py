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

def print_results(package,match_dict):
    print("To do")

def choose(package,repo_list):
    ask("To do","Y")
    return repo_list[0] # To do

def search(package, match=False):

    if match and ".pacscript" in package:
        from os.path import exists
        return package if exists(package) else -1

    repo_list=get_repolist()
    repo = None

    if "@" in package:
        pkg_name, repo = package.split("@",1)

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
                match_list.append(f'repo_url/packages/{package}/{package}.pacscript')
        
        packagelist = get_local()
        if match and exact_match(package,get_local()):
             match_list.append(f"./{pgkname}.pacscript")

        if match_list:
            return choose(match_list)
        
        fancy("error", f"Package {pkg_name} not found")       
        return -1

    match_dict = {}

    for repo in repo_list:
        packagelist = get_packagelist(repo_list[repo])
        for pkg in partial_match(package,packagelist):
            if repo in match_dict:
                match_dict[repo]+=[pkg]
            match_dict[repo]=[pkg]
    
    packagelist = get_local()
    match_local = partial_match(package,package_list)
    for pkg in partial_match(package,packagelist):
        if 'local' in match_dict:
            match_dict['local']+=[pkg]
        match_dict['local']=[pkg]

    print_results(package, match_dict)
    return 0
            