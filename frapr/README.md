# frapr

A collection of R scripts for averaging and normalizing FRAP data.

This code is fairly old and full of rookie mistakes, but it works. Assumes that
each numbered script will be ran sequentially, and that all data for a single
experiment are in one folder. Loads files named `experiment ID_patch.txt`,
`experiment ID_cell.txt`, `experiment ID_background.txt` and assumes these are
respectively the bleached ROI, the photobleaching correction ROI and the
background correction ROI for a single experiment.

The two subfolders, `double_normalization` and `tirf` correspond
to the two scenarios from the paper

`double_normalization` follows the classic normalization procedure and fit
as described in Phair, R. D., Gorski, S. A., & Misteli, T. (2004). Measurement
of dynamic protein binding to chromatin in vivo, using photobleaching
microscopy. *Methods in Enzymology*, 375, 393–414.
https://doi.org/10.1016/s0076-6879(03)75025-3

`tirf` is a modification of the first set of scripts to account for particular
quirks of our FRAP in TIRF setup. It aligns multiple FRAP events from single 
movies, removing multiple consecutive bleach frames. It also disregards 
photobleaching correction, as we considered it impractical
to correct, and of negligible importance.
