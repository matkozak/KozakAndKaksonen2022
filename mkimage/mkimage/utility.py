# import numpy and skimage modules
import numpy as np
import skimage as sk
import tifffile as tiff
from skimage import filters, morphology


def max_project(im):
    """ Return a maximum Z-projection of a 3D image. """
    if im.ndim == 3:
        im_max = np.amax(im, 0)
        return im_max
    else:
        print("Error: 3-dimensional stack required")
        return None


def median_filter(im, radius):
    """
    Median filter a 2D/3D image using a circular brush of given radius.
    On a 3D image, each slice is median-filtered separately using a 2D structuring element.
    """
    if len(im.shape) == 2:
        im_median = filters.median(im, morphology.disk(radius))
    elif len(im.shape) == 3:
        # initialize empty image
        im_median = np.zeros(shape=im.shape, dtype=im.dtype)
        # fill empty image with median-filtered slices
        for i in range(im.shape[0]):
            im_median[i, :, :] = filters.median(
                im[i, :, :], morphology.disk(radius))
    else:
        print('Cannot deal with the supplied number of dimensions.')
        return None
    return im_median


def subtract_median(im, radius):
    """ Performs median filtering and subtracts the result from original image. """
    im_median = median_filter(im, radius)
    # microscope .tif files are uint16 so subtracting below 0 causes integer overflow
    # for now using np method to cast to int64, skimage function goes back to image
    im_spots = im.astype(int) - im_median.astype(int)
    return sk.img_as_uint(im_spots)


def threshold(im, method):
    '''
    Wrapper function for common thresholding methods.
    Takes an array and a method string, one of:
    'li', 'otsu', 'triangle' or 'yen'.
    Returns the threshold value.
    '''
    # set up a method dictionary
    thresholding_methods = dict(
        li = filters.threshold_li,
        otsu = filters.threshold_otsu,
        triangle = filters.threshold_triangle,
        yen = filters.threshold_yen
    )

    # check if the supplied method is valid
    if method not in thresholding_methods.keys():
        print('Specified thresholding method not valid. Choose one of:')
        print(*thresholding_methods.keys(), sep = '\n')
        return None
    
    return thresholding_methods[method](im)


def mask_cell(im, radius=10, method = 'otsu', max=False):
    """
    Return a mask (boolean array) based on thresholded median-filtered image.

    Parameters
    ----------
    im: array-like
        Image to be masked.
    radius: int, optional
        Radius for the median filtering function.
    method: int, optional
        Which thresholding method to use. See treshold() function.
    max: bool, optional
        If True, performs maximum projection of a 3D stack prior to thresholding.
    
    Notes
    -----    
    To apply mask: im[mask_cell(im)] produces a flat array of masked values.
    im * mask_cell(im) gives a masked image.
    """
    im_median = median_filter(im, radius)
    # maximum project
    if max:
        im_median = max_project(im_median)
    # threshold
    threshold_value = threshold(im_median, method)
    im_mask = im_median > threshold_value
    # return masked image
    return im_mask


def cell_area(im, radius=10):
    """ Return pixel area estimate of cell cross section.
    Only one ROI per image is counted so thresholding has to be unambiguous. """
    im_mask = mask_cell(im, max=True)
    area = np.sum(im_mask)
    return area


def collate_stacks(*args):
    """
    Takes 3D stacks and concatenates them in the order z, channel, x, y.
    Rationale: tifffile can save ImageJ hyperstacks, but expects this order.
    Leaving this here for now, but actually np.swapaxes() works just fine for this.
    """
    if not all(i.shape == args[0].shape for i in args):
        print('stacks need to be the same dimensions')
        return None
    im_list = [np.expand_dims(im, 1) for im in args]
    im_out = np.concatenate(im_list, 1)
    return im_out
    

def erode_alternative(im, n):
    """
    Same as erode_3d; takes an image and a number of connections n.
    A pixel is eroded if there is less than n non-zero pixels surrounding it.
    This was supposed to be cleaner and faster than erode_3d and it sometimes is,
    but it is often much slower (~10x). erode_3d is more consistent.
    """
    # process input image: binarize and pad
    im = (im > 0.5).astype(int)
    im = np.pad(im, 1)

    im_out = im.copy()
    index = np.argwhere(im)

    for i in index:
        z, y, x = i[0], i[1], i[2]
        # calculate the sum of the cube around nonzero pixel
        cube_sum = np.sum(im[z-1:z+2, y-1:y+2, x-1:x+2]) - 1
        # zero pixels below threshold connections
        if cube_sum < n:
            im_out[tuple(i)] = 0

    im_out = im_out[1:-1, 1:-1, 1:-1].astype(int)
    return im_out


def erode_3d(image, n):
    """
    Performs a three dimensional erosion on binary image. The 3D brush represents all
    possible positions in a cubic array around the eroded pixel while the n parameter
    specifies how many connections a pixel needs to have to be preserved.
    I.e.: n = 26 means that a pixel is eroded unless it is completely surrounded by 1's,
    n = 1 means that the pixel is preserved as long as it has 1 neighbour in 3D.
    """

    if n == 0:
        n = 1
        print("n set to 1; smaller values will not do anything")
    if n > 26:
        n = 26
        print("n set to 26; number of neighbor pixels cannot exceed 26")

    brush = np.array([
        [  # 0
            [
                [1, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 1
            [
                [0, 1, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 2
            [
                [0, 0, 1],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 3
            [
                [0, 0, 0],
                [1, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 4
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 5
            [
                [0, 0, 0],
                [0, 0, 1],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 6
            [
                [0, 0, 0],
                [0, 0, 0],
                [1, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 7
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 1, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 8
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 1]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 9
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [1, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 10
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 1, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 11
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 1],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 12
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 1],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 13
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 1]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 14
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 1, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 15
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [1, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 16
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [1, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 17
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [1, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 18
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 1, 0],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 19
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 1],
                [0, 0, 0],
                [0, 0, 0]],
        ],
        [  # 20
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [1, 0, 0],
                [0, 0, 0]],
        ],
        [  # 21
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
        ],
        [  # 22
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 1],
                [0, 0, 0]],
        ],
        [  # 23
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [1, 0, 0]],
        ],
        [  # 24
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 1, 0]],
        ],
        [  # 25
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 1, 0],
                [0, 0, 0]],
            [
                [0, 0, 0],
                [0, 0, 0],
                [0, 0, 1]],
        ]
    ])

    image = np.pad(image, 1)
    eroded_images = np.zeros(shape=image.shape, dtype=int) # can't sum pure bools

    for i in range(26):
        tmp = morphology.binary_erosion(image, brush[i, :, :, :])
        eroded_images += tmp

    image_out = eroded_images >= n
    image_out = image_out[1:-1, 1:-1, 1:-1]

    return image_out

