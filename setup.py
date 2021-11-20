from setuptools import setup

setup(name='pacstall',
      version='2.0-dev0',
      maintainer='pacstall',
      url='https://github.com/pacstall/pacstall',
      packages=['pacstall','pacstall.api'],
      package_dir={'pacstall':'src'},
      zip_safe=False,
      description='An AUR-inspired package manager for Ubuntu ',
      license="GPLv3",
      )
