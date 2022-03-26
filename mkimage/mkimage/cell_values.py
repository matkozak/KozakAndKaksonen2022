# import modules for handling files
import csv
from pathlib import Path
from sys import argv

# import third-party packages
import numpy as np
import tifffile as tiff
from skimage import img_as_ubyte
from skimage.morphology import binary_opening
#from scipy.ndimage import generate_binary_structure

# import utility functions
from .utility import mask_cell

# %%
def batch_mask(path, pattern='GFP', mask_channel=None,
               camera_bits=16, r=10, method='triangle', mask_open=True,
               save_values=False, save_summary=False, save_mask=False):
    """
    Read all .tif images with a keyword and apply a 3D masking procedure
    based on a median-filtered image.

    Returns
    -------
    dict
        Key is the image name, value is a flat array of all intensities in the masked image.

    Parameters
    ----------

    path: str
        A path to folder with images to be processed. Must contain images in TIFF format.
    pattern: str, optional
        A pattern within filenames to be processed.
    mask_channel: str, optional
        If specified, the mask is created based on another image. 
        Both images have to have the same name, except *mask_channel* is substituted for *pattern*.
    camera_bits: int, optional
        Ignore images with saturated pixels, based on the camera digitizer bit-depth.
    r: int, optional
        Radius for the median filtering function.
    method: str, optional
        Which thresholding method to use. See .utility.treshold().
    mask_open: bool, optional
        If True, perform a binary opening of the mask with the default selem (3D cross).
    save_values: bool, optional
        If True, write one .txt file per image with all pixel values.
    save_summary: bool, optional
        If True, write one .csv file per image with summary statistics (mean, median, sd).
    save_mask: bool, optional
        If True, save masks as 8-bit .tif files.
    """
    # path handling through Pathlib: make output folder within current path
    path_in = Path(path)
    # initialise a dictionary to store results
    pixels = {}

    # output: prepare folder to keep masks
    if save_mask:
        path_out = path_in.joinpath('masks')  # prepare output path
        path_out.mkdir(parents=True, exist_ok=True)
        
    # actual function: loop over each file with pattern, mask and convert to array
    for i in sorted(path_in.glob('*' + pattern + '*')):
        im = tiff.imread(str(i))
        
        # filter out saturated images
        if 2 ** camera_bits - 1 in im:
            continue

        # generate and apply mask
        if mask_channel:
            im_alt = tiff.imread(str(i).replace(pattern, mask_channel))
            im_mask = mask_cell(im_alt, radius=r, method=method)
            if mask_open:
                im_mask = binary_opening(im_mask)
            im_values = im[im_mask]  # mask and select values
        else:    
            im_mask = mask_cell(im, radius=r, method=method)
            if mask_open:
                im_mask = binary_opening(im_mask)
            im_values = im[im_mask]  # mask and select values

        # add dictionary entry with name (no extension) and pixel values
        pixels[i.name.replace('.tif', '')] = im_values

        # output: save masks in a subfolder
        if save_mask:
            # substitute channel and / or annotate mask in filename
            if mask_channel:
                mask_out = path_out.joinpath(i.name.replace(
                    pattern, mask_channel).replace('.tif', '_mask.tif'))
            else:
                mask_out = path_out.joinpath(
                    i.name.replace('.tif', '_mask.tif'))
            tiff.imsave(mask_out, img_as_ubyte(im_mask))
            # very useful for assessing the algorithm but ultimately waste of space
            tiff.imsave(path_out.joinpath(i.name.replace('.tif', '_masked.tif')),
                im * im_mask)

    # output: save each dictionary entry as separate file in a subfolder
    if save_values:
        path_out = path_in.joinpath('masked_arrays')  # prepare output path
        f = '%i'  # not quite necessary but the default 18-digit precision means relatively huge files
        path_out.mkdir(parents=True, exist_ok=True)
        # save array
        for key, value in pixels.items():
            np.savetxt(str(path_out.joinpath(key))+'.txt', value, fmt=f)

    # output: save a csv file with mean intensity for each cell
    if save_summary:
        path_out = path_in.joinpath("summary.csv")
        with path_out.open('w', newline='') as f:  # initialize a csv file for writing
            # initialize csv writer and write headers
            writer = csv.writer(f, dialect='excel')
            writer.writerow(['cell', 'mean', 'median', 'sd'])
            for key, value in pixels.items():
                writer.writerow([key, round(np.mean(value), 3),
                                 np.median(value), round(np.std(value), 3)])

    # output: return dictionary of masked pixels
    return(pixels)


# get the path from command line and run counting function
if __name__ == "__main__":  # only executed if ran as script
    path = argv[1]
    batch_mask(path, save_summary=True)
