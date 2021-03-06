#!/usr/bin/env bash

# Make sure we fail in case of errors
set -e

# Copy sources (we do not have write permission on the mounted $TRAVIS_BUILD_DIR),
# so let's make a copy of the source code
cd ~
rm -rf my_work_dir
mkdir my_work_dir
# Copy also dot files (.*)
shopt -s dotglob
cp -R ${TRAVIS_BUILD_DIR}/* my_work_dir/

cd my_work_dir

# Get the version in the __version__ environment variable
python ci/set_minor_version.py --patch $TRAVIS_BUILD_NUMBER --version_file astromodels/version.py

export PKG_VERSION=$(cd astromodels && python -c "import version;print(version.__version__)")

echo "Building ${PKG_VERSION} ..."

echo "Testing with XSPEC: ${TEST_WITH_XSPEC} ..."


# Update conda
conda update --yes -q conda conda-build

# Answer yes to all questions (non-interactive)
conda config --set always_yes true

# We will upload explicitly at the end, if successful
conda config --set anaconda_upload no

# Create test environment
conda create --name test_env -c conda-forge python=$TRAVIS_PYTHON_VERSION pytest codecov pytest-cov git

# Make sure conda-forge is the first channel
conda config --add channels conda-forge

conda config --add channels defaults

# Activate test environment
source activate test_env

# Build package

if $TEST_WITH_XSPEC ; then
    echo "Building WITH xspec"
    
    conda build -c conda-forge -c threeml --python=$TRAVIS_PYTHON_VERSION conda-dist/recipe
    conda install --use-local -c conda-forge -c threeml astromodels xspec-modelsonly-lite
else

    if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
	
	conda build -c conda-forge -c threeml --python=$TRAVIS_PYTHON_VERSION conda-dist/no_xspec_recipe

    else

	# there is some strange error about the prefix length

	conda build --no-build-id  --python=$TRAVIS_PYTHON_VERSION conda-dist/no_xspec_recipe
    fi
	
    conda install --use-local -c conda-forge -c threeml astromodels 
fi

    
# Run tests
cd astromodels/tests
python -m pytest -vv --cov=astromodels # -k "not slow"

# Codecov needs to run in the main git repo

# Upload coverage measurements if we are on Linux
if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then

    echo "********************************** COVERAGE ******************************"
    codecov -t 493c9a2d-42fc-40d6-8e65-24e681efaa1e

fi



# We do not want to upload if we do not test with xspec

if $TEST_WITH_XSPEC ; then


    # If we are on the master branch upload to the channel
    if [[ "${TRAVIS_EVENT_TYPE}" == "pull_request" ]]; then

        echo "This is a pull request, not uploading to Conda channel"

    else

        if [[ "${TRAVIS_EVENT_TYPE}" == "push" ]]; then

            echo "This is a push, uploading to Conda channel"

            conda install -c conda-forge anaconda-client

            echo "Uploading ${CONDA_BUILD_PATH}"
            
            if [[ "$TRAVIS_OS_NAME" == "linux" ]]; then
                
                anaconda -t $CONDA_UPLOAD_TOKEN upload -u threeml /opt/conda/conda-bld/linux-64/*.tar.bz2 --force
		
            else
		
                anaconda -t $CONDA_UPLOAD_TOKEN upload -u threeml /Users/travis/miniconda/conda-bld/*/*.tar.bz2 --force
		
            fi
        fi
    fi
else
    echo "We didn;t test with xspec, not uploading"
    
fi
