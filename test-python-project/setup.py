from setuptools import setup, find_packages

setup(
    name="test-python-project",
    version="0.1.0",
    description="A test Python project for Claude Nights Watch",
    packages=find_packages(),
    install_requires=[
        "requests",
    ],
    python_requires=">=3.7",
)
