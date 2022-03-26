#!/usr/bin/env python

from setuptools import setup

setup(name='mkimage',
      version='0.3',
      description='A collection of image-processing utilities',
      url='',
      author='Mateusz Kozak',
      author_email='mateusz.kozak@unige.ch',
      license='MIT',
      packages=['mkimage'],
      install_requires=[
          'numpy',
          'scikit-image'
      ],
      zip_safe=False)

