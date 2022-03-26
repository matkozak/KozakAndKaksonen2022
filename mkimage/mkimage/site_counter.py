# import modules for handling files
import csv
from pathlib import Path
from sys import argv

# import third-party packages
import numpy as np
import skimage as sk
import tifffile as tiff
from skimage.measure import label
from skimage.exposure import rescale_intensity

# import utility functions
from .utility import (cell_area, erode_3d, mask_cell, threshold, subtract_median)


def count_patches(im, median_radius=10, erosion_n=3, con=2,
                  method='yen', mask=False, loop=False):

    """
    Count the number of spots and the cross-section area in a 3D image of a single yeast cell.
    
    Input:
    Takes a 3D stack. Performs median filter subtraction, followed by thresholding and 3D erosion.

    Returns:
     - count, int: a number of areas remaining after erosion (number of patches)
     - area, int: the number of nonzero pixels in median-filtered, maximum projected
     and Otsu-thresholded image (cross-section area)
     - images, arr: a hyperstack consisting of three volumes: image after median filter subtraction,
     after thresholding and after erosion. Note: this displays well in pyplot, but axes need to be swapped to save
     as ImageJ compatible .tif

    Parameters:
     - median_radius, int: each slice will be median-filtered with a disk of this radius (default 10)
     - erosion_n, int: a pixel will be eroded unless it has this number of non-zero neighbours in 3D (default 3)
     - con, int: connectivity setting for label function, refer to scikit-image docs (default 2)
     - method, str: method for thresholding; refer to .utility.threshold docstring for a list of allowed methods (default 'yen')
     - mask, bool: if True, spot thresholding ignores background *outside* of the cell (default False)
     - loop, bool: if True, erosion iterates until the image stops changing (default False)
    """

    im_spots = subtract_median(im, median_radius)

    if mask:
        im_masked = im_spots[mask_cell(im)]
        threshold_value = threshold(im_masked, method)
    else:
        threshold_value = threshold(im_spots, method)

    # threshold
    im_threshold = im_spots > threshold_value
    
    # erode
    if loop: # one day, put looping in the erosion function
        im_eroded = im_threshold.copy()
        im_check = np.ones(shape=im_eroded.shape,
                            dtype=im_eroded.dtype)
        # loop erosion as long as the image is changing
        while not np.array_equal(im_check, im_eroded):
            im_check = im_eroded.copy()
            im_eroded = erode_3d(im_eroded, erosion_n)
    else:
        im_eroded = erode_3d(im_threshold, erosion_n)


    # use label to get eroded image with patch labels and count with total number
    im_eroded, count = label(
        im_eroded, connectivity=con, return_num=True)

    # get out area
    area = cell_area(im)
    
    # prepare a hyperstack with MD, threshold and eroded images
    images = np.array([im_spots, im_threshold, im_eroded])

    return count, area, images


def process_folder(path, pattern='*GFP*',
                   median_radius=10, erosion_n=3, con=2, method='yen',
                   mask=False, loop=False, save_images=False):
    """
    Runs the patch counter function for every image in given path that matches pattern,
    GFP by default. If save_images, the intermediate processed images are saved
    (median filter subtracted, thresholded and final eroded and labeled image).
    """

    # initialize paths: in/out dirs and output file for numbers
    # using pathlib/Path makes it easier to create folders an manipulate paths than os

    inPath = Path(path)
    outPath = inPath.joinpath(method
                              + '_r' + str(median_radius)
                              + '_n' + str(erosion_n)
                              + '_con' + str(con)
                              + '_mask' * mask
                              + '_loop' * loop)
    outPath.mkdir(parents=True, exist_ok=True)
    outCsv = outPath.joinpath(method + '_n' + str(erosion_n) + "_count.csv")

    with outCsv.open('w', newline='') as f:  # initialize a csv file for writing

        # initialize csv writer and write headers
        writer = csv.writer(f, dialect='excel')
        writer.writerow(['Cell', 'Threshold', 'Patches', 'Cross_Area'])

        # iterate over files
        for i in sorted(inPath.glob(pattern)):  # glob returns pattern-matching files

            # join the output path and image name
            im_path = outPath.joinpath(i.name)

            # read image
            im = tiff.imread(str(i))

            # use counting function
            count, area, images = count_patches(im,
                                                median_radius = median_radius,
                                                erosion_n = erosion_n,
                                                con = con,
                                                method = method,
                                                mask = mask,
                                                loop = loop)

            # save patch count and area with csv writer
            writer.writerow([i.name.replace('.tif', ''),
                             method, str(count), area])

            if save_images: 
                # save median-subtracted image as 16-bit
                im_spots = images[0, :, :, :]
                im_spots = sk.img_as_uint(im_spots)
                tiff.imsave(str(im_path).replace(pattern, '').replace(
                    '.tif', '_MD.tif'), im_spots)

                # convert boolean into 16-bit image
                im_thresholded = images[1, :, :, :]
                im_thresholded = sk.img_as_uint(im_thresholded)
                tiff.imsave(str(im_path).replace(pattern, '').replace(
                    '.tif', '_Thresholded_' + method + '.tif'), im_thresholded)

                # save enumerated sites as 16-bit
                im_eroded = images[2, :, :, :]
                im_eroded = sk.img_as_uint(im_eroded)
                tiff.imsave(str(im_path).replace(pattern, '').replace(
                    '.tif', '_Eroded' + '_n' + str(erosion_n) + '.tif'), im_eroded)

# get the path from command line and run counting function
if __name__ == "__main__": # only executed if ran as script
    path = argv[1]
    method = str(argv[2])
    n = int(argv[3])
    process_folder(path, median_radius = 5, erosion_n = n, con = 2,
                   method = method, mask = True, loop = False, save_images = True)
