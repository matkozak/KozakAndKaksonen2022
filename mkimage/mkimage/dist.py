import numpy as np
import tifffile as tiff

from .utility import (mask_cell, max_project)
from skimage.exposure import rescale_intensity
from skimage import img_as_ubyte

# import modules for handling files
from pathlib import Path
from sys import argv

def rescale_x(p):
    """ takes p(i) array and rescales all i values by a factor of integral """
    p_sum = np.sum(p, axis=0)[1]
    i = (p[:, 0] - p[0, 0]) / p_sum
    p[:, 0] = i

    return p


def prob_dist(im, make_float=False, rescale=True, make_8b=False):
    """
    takes an image and returns (1) a sorted array of pixel intensities i
    and (2) probability that random pixel from array is bigger than i
    """
    if make_8b == True:
        im = img_as_ubyte(rescale_intensity(im, out_range='uint8'))

    # perform a maximum projection on image, calculate a cell mask and apply to image
    im_mask = mask_cell(im, max=True)
    im_max = max_project(im)
    im_masked = im_max * im_mask
    # establish min/max pixel values of rescaled images
    px_min = np.min(im_masked[np.nonzero(im_masked)])
    px_max = np.max(im_masked)

    # optional and mostly untested: im_float param forces (masked) picture into floating (0,1) range
    if make_float == True:
        prob = np.array([np.arange(0, 1.001, 0.001), np.zeros(1001)]).T
        im_masked = rescale_intensity(im_masked, out_range='float64')
    else:
        prob = np.array([np.arange(px_min, px_max + 1),
                         np.zeros(px_max - px_min + 1)]).T

    # calculate p(i) = P (image > i)
    for row in prob:
        i = row[0]
        p = np.sum(im_masked >= i) / np.sum(im_mask)
        row[1] = p

    # rescaling by a factor of integral on by default
    if rescale == True:
        rescale_x(prob)

    return prob, im_masked


def prob_dir(path, pattern='*GFP*', rescale=True, make_8b=False):
    # initialize paths: in/out dirs and output file for numbers
    # using pathlib/Path makes it easier to create folders an manipulate paths than os
    inPath = Path(path)
    outPath = inPath.joinpath('thresholdDistribution')
    outPath.mkdir(parents=True, exist_ok=True)
    for i in inPath.glob(pattern):  # glob returns pattern-matching files

        # get the name of image i to modify later
        im_path = outPath.joinpath(i.name)

        # read image
        im = tiff.imread(str(i))

        # use the function to do the thing
        prob, im_masked = prob_dist(im, rescale=rescale, make_8b=make_8b)

        # save maxed and masked image
        tiff.imsave(str(im_path).replace('.tif', '_Masked.tif'), im_masked)

        # save array
        np.savetxt(str(im_path).replace('.tif', '.txt'), prob)

def im_skew(im):
    im_mask = mask_cell(im)
    im_masked = im[im_mask]
    s = (np.mean(im_masked) - np.median(im_masked)) / np.std(im_masked)
    return s
