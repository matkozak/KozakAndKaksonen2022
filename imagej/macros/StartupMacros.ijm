/*
###############################
#### USER MACROS START HERE ###
###############################
*/

/*
#################
### Functions ###
#################
*/


function check4pic() {
	if (nImages == 0) exit("open an image");
}

function check4stack() {
	if (nSlices == 0) exit("open a stack");
}

function pic2stack() {
	if (nSlices == 0) run("Convert Images to Stack");
}

function check4ROItype(mintype, maxtype, notype) {
/*
Force the user to make a selection of particular type (or type range).

Returns an error message when slection is outside of allowed range.

-1: no selection,
0: rectangle, 1: oval, 2: polygon, 3: freehand, (areas)
4: traced, 5: straight line, 6: segmented line, 7: freehand line, (lines)
8: angle, 9: composite and 10: point.

Input
=====

mintype, maxtype: range of allowed selection types
notype: disallowed selection type
*/
	if (
      (selectionType() < mintype) || 
      (selectionType() > maxtype) || 
      (selectionType() == notype) || 
      (selectionType() == -1)
    ){
		if ((mintype == 3) && (maxtype == 7)) exit("select a line ROI");
		if ((mintype == 0) && (maxtype == 3)) exit("select an area ROI");
		else exit("select a suitable ROI");
	}
}

function bgSubNorm(radius,method) {
/*
Perform rolling ball background subtraction on active image (single slices).
Perform rolling ball background subtraction and photobleaching correction
on active image (stacks).
Macros have to handle file opening and saving.
The mask used is saved in the folder image by the function however.

Input
=====

Radius for BG subtraction (80 is a good default for the IX81 camera)
and tresholding method (Triangle works well, also Li).
*/

	if (nSlices()<2) {
		run("Subtract Background...", "rolling=" + radius + " stack");
	}

	else {
		im = getTitle();
		dir = getDirectory("image");
		
		// set stage; reset everything
		run("Select None");
		run("Set Slice...", "slice=" + 1);
		run("Set Measurements...", "mean redirect=None decimal=9");
		// setBatchMode("hide");

		// subtract bg and create mask
		run("Subtract Background...", "rolling=" + radius + " stack");
		run("Duplicate...", "duplicate range=1-1 title=ToGetMask.tif");
		run("Auto Threshold", "method=" + method + " white");
		run("Convert to Mask");

		// save masks in separate dir
		masks = dir + "masks" + File.separator;
		File.makeDirectory(masks);
		im_mask = replace(im, ".tif", "_" + method + ".tif");
		saveAs("Tiff", masks + im_mask);

		run("Create Selection");
		close();
		selectWindow(im);

//	run("Select None");
	
		for(l=0; l<nSlices+1; l++) {
			run("Restore Selection");
			run("Clear Results");
			run("Measure");
			picsum = getResult("Mean",0);

			if(l==0){
				picsum1 = picsum;
			}

			int_ratio = picsum1 / picsum;
			run("Select None");
			run("Multiply...", "slice value=" + int_ratio);
			run("Next Slice [>]");
		} 
		
		// setBatchMode("show");
		selectWindow("Results");
		run("Close");
	}
}

function bgSubNormRed(radius,method) {
/*
Modification of bgSubNorm that takes in an RFP stack (requires the same filename)
and uses it to create mask for photobleaching correction on a GFP stack.

Perform rolling ball background subtraction on active image (single slice).
Perform rolling ball background subtraction and photobleaching correction on active image (stacks).
Macros have to handle file opening and saving.
The mask used is saved in the folder image by the function however.

Input
=====

Radius for BG subtraction (80 is a good default for the IX81 camera) and tresholding method.
*/

	if (nSlices()<2) {
		run("Subtract Background...", "rolling="+radius+" stack");
	}

	else {
		im_GFP = getTitle();
		im_RFP = replace(im_GFP, "GFP", "RFP");
		dir = getDirectory("image");
		
		// set stage; reset everything
		run("Select None");
		run("Set Slice...", "slice="+1);
		run("Set Measurements...", "mean redirect=None decimal=9");
		setBatchMode("hide");

		// bgSub on GFP	
		run("Subtract Background...", "rolling="+radius+" stack");

		// bgSub and mask on RFP
		open(dir + im_RFP);
		run("Select None"); // this is crazy but for some reason on test images ImageJ was making a tiny selection that changed the threshold behaviour
		run("Subtract Background...", "rolling="+radius+" stack");
		run("Auto Threshold", "method="+method+" white stack");

		run("Convert to Mask", "method=Default background=Dark calculate black");

		// save masks in subfolder
		masks = dir + "masks" + File.separator;
		File.makeDirectory(masks);
		im_mask = replace(im_RFP, ".tif", "_"+method+".tif");
		saveAs("Tiff", masks + im_mask);

		for(l=0; l<nSlices+1; l++) {
			
			//get mask from RFP and move slice
			selectWindow(im_mask);
			run("Create Selection");
			run("Next Slice [>]");

			// go back to GFP and proceed as usual
			selectWindow(im_GFP);
			run("Restore Selection");
			run("Clear Results");
			run("Measure");
			picsum = getResult("Mean",0);

			if(l==0){
				picsum1 = picsum;
			}

			int_ratio = picsum1 / picsum;
			run("Select None");
			run("Multiply...", "slice value=" + int_ratio);
			run("Next Slice [>]");
		}
		
		// clean up view
		selectWindow(im_mask);
		close();
		selectWindow("Results");
		run("Close");
		setBatchMode("show");
	}
}

function subtractMedian(r) {
/*
Returns the result of subtracting a median-filtered copy from the active image.

Input: filter radius in px.
*/

	name = getTitle();
	run("Duplicate...","title=mask duplicate");
	run("Median...", "radius=" + r + " stack");
	imageCalculator("Subtract create stack",name,"mask");
	selectWindow("mask");
	close();
}

function max8b() {
/*
Returns an 8-bit version of the active image.
If the image is a stack, preserves maximum dynamic range across the entire stack.
*/

  title = getTitle();
	
	if (nSlices() == 1) {
		resetMinAndMax();
		run ("8-bit");
	} else {
		run("Set Measurements...", " min redirect=None decimal=9");
		run("Z Project...", "start=1 stop="+nSlices()+" projection=[Max Intensity]");
		run("Measure");
		max = getResult("Max", 0);
		run("Clear Results");	
		close();
		run("Z Project...", "start=1 stop="+nSlices()+" projection=[Min Intensity]");
		run("Measure");
		min = getResult("Min", 0);
		close();
		selectWindow("Results");
		run("Close");
		selectWindow(title);
		setMinAndMax(min, max);
		run("8-bit");
	}
}

function indexify(number, width, character) {
/*
Convert number to an index format string (e.g. '001' instead of 1).

Input: number to convert, desired number of characters, character to pad with
(e.g. 83, 4, 0 to change '83' into '0083').
*/

	number = toString(number); // force string
	character = toString(character); // specify character to add, almost always 0
	for (len = lengthOf(number); len < width; len++)
		number = character + number;
	return number;
}

function planeTimings(path) {
/*
Get time metadata (plane deltas) from a file that allows it via the Bio-Formats extension.

Returns a list of plane deltas (time elapsed since previous acquisition),
	average plane delta.

Input: path to file

Important: when using this functions in macros,
	place 'run("Bio-Formats Macro Extensions");' before the function
*/

	Ext.setId(path);
	
	z = File.getName(path);
	Ext.getImageCount(imageCount);
	z += "\nPlane count: " + imageCount;
	
	date = "";
	Ext.getImageCreationDate(date);
	z += "\nCreation date: " + date;

	abs_delta = newArray(imageCount);
	Ext.getPlaneTimingDeltaT(abs_delta[0], 0); // this is a bit silly but I'll do it to be consistent
	rel_delta = newArray(imageCount-1);
	exposureTime = newArray(imageCount);
	Ext.getPlaneTimingExposureTime(exposureTime[0], 0); // same here

	z += "\nPlane deltas (seconds since previous plane):";
	z += "\n1: " + abs_delta[0] + " s" + " [exposed for " + exposureTime[0] + " s]";
	
	for (i=1; i<imageCount; i++) {
		Ext.getPlaneTimingDeltaT(abs_delta[i], i);
		Ext.getPlaneTimingExposureTime(exposureTime[i], i);
		if (abs_delta[i] == abs_delta[i]) { // not NaN
			rel_delta[i-1] = abs_delta[i] - abs_delta[i-1];
			z += "\n" + (i + 1) + ": " + rel_delta[i-1] + " s";
			if (exposureTime[i] == exposureTime[i]) { // not NaN
				z = z + " [exposed for " + exposureTime[i] + " s]";
			}
		}	 
	}
	Array.getStatistics(rel_delta, min, max, mean, stdDev);
	
	z += "\n\nAverage plane delta: " + mean + " +/- " + stdDev + " SD\n";
	
	return z;
}

function randomInt(n) {
/*
Returns a random integer k such as 0 <= k <= n

Input: n
*/
	k = round(n * random());
	return k;
}

function shuffle(array) {
/*
Randomize contents of an array using Fisher-Yates shuffle.
The modification is done on the array itself, not a copy.

Input: array
*/
	n = array.length - 1;  // The number of items left to shuffle (loop invariant).
	while (n > 0) {
		k = randomInt(n);     // 0 <= k <= n.
		temp = array[n];  // swap array[n] with array[k] (does nothing if k==n).
		array[n] = array[k];
		array[k] = temp;
		n--;                  // n is now the last pertinent index;
	}
}

/*
#############
### Tools ###
#############
*/



/*
####################
### Basic macros ###
####################
*/

macro "Save as .tif [T]" {
/*
Shortcut to the save command.
*/
	saveAs("Tiff");
}

macro "Save all as .tif" {
/*
Save all open images in chosen directory.
*/
  dir = getDirectory("Choose a Directory");
  for (i=0;i<nImages;i++) {
          selectImage(i+1);
          title = getTitle;
          print(title);
          saveAs("tiff", dir + title);
  }
  run("Close All");
}

macro "stk2Tif_batch" {
/*
Batch convert .stk files to .tif using BioFormats importer.
Preserves pixel size metadata and saves the plane time information.
Has a significant drawback of duplicating data.
I *think* that most if not all metadata is preserved,
so the .stk's could be deleted... but do it at your own discretion.

Input: folder of .stk files

Output: folder of .tif files, .txt files with deltas and averages
*/
	dir = getDirectory("Choose data directory");
	list = getFileList(dir);
	run("Bio-Formats Macro Extensions");
	setBatchMode(true);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], ".stk")) {
//			open(dir+list[i]);
			Ext.openImagePlus(dir+list[i]);
			title = getTitle();
			
			times = planeTimings(dir + title);
			
			stk2tif = dir + "stk2tif" + File.separator;
			File.makeDirectory(stk2tif);

			title_tif = replace(title, ".stk", ".tif");
			saveAs("Tiff", stk2tif + title_tif);
			
			close();
			
			File.saveString(times, dir + replace(list[i],".stk", "_times.txt"));
		}
	}
	setBatchMode(false);
}

macro "nd2Tif_batch" {
/*
Batch convert multi-file, two-color timelapse stacks with .nd files
to .tif using BioFormats importer.
Written hastily for a particular set of stacks from the IX81, might be sloppy.

Input: folder of multi-file two-color stacks with .nd metadata files

Output: folder of .tif files, .txt files with deltas and averages
*/

	dir = getDirectory("Choose data directory");
	list = getFileList(dir);
	run("Bio-Formats Macro Extensions");
	setBatchMode(true);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], ".nd")) {
//			open(dir+list[i]);
			Ext.openImagePlus(dir+list[i]);
			title = getTitle();
			
			times = funcPlaneTimings(dir + title);
			
			rfp = replace(list[i], ".nd", "_RFP.tif");
			gfp = replace(list[i], ".nd", "_GFP.tif");

			run("Split Channels");
			nd2tif = dir + "nd2tif" + File.separator;
			File.makeDirectory(nd2tif);
			
			selectWindow("C1-" + title);
			saveAs("Tiff", nd2tif + rfp);
			close();

			selectWindow("C2-" + title);
			saveAs("Tiff", nd2tif + gfp);
			close();
			
			File.saveString(times, dir + replace(list[i],".nd", "_times.txt"));
		}
	}
	setBatchMode(false);
}

/*
#######################
### TESTING GROUNDS ###
#######################
*/

/*
####################
### MEASUREMENTS ###
####################
*/

macro "blindAnalysis" {
/*
Randomly pick images from a folder and assign them a numeric phenotype value.
Writes a .csv file with image names and assigned phenotypes.

Filenames will be hidden during assignment, but preserved in the output.
A way to distinguish the genetic background (e.g. strain number) 
needs to be contained in the filenames.

Input
=====

Folder of all .tif images to be analysed.
Phenotype levels: the number of different phenotypes (default is binary).
*/

	dir = getDirectory("Choose input Directory");
	list = getFileList(dir);
	shuffle(list);

	Dialog.create("Levels");
	Dialog.addNumber("Number of phenotype levels (including wt):", 2);
	Dialog.show();
	levels = Dialog.getNumber();

	choices = Array.getSequence(levels);
	for (i = 0; i<lengthOf(choices); i++){
	// convert choices to strings, looks better and works better when reading csv
		choices[i] = d2s(choices[i],0);
	}

	out = "";

	for (i=0; i<(list.length); i++) {
		showProgress(i, list.length);
		if (endsWith(list[i], ".tif")) {

			setBatchMode(true);
			open(dir + list[i]);
			title = getTitle();
			rename("random image");
			
			if (i > 0) { // preserve display range from previous image
				setMinAndMax(min, max);
			}
			
			setBatchMode(false);
			
			phenotype = "null";
			while (phenotype == "null") {
				Dialog.createNonBlocking("Phenotype"); // allows image manipulation
				Dialog.addRadioButtonGroup("Phenotype:", choices, levels, 1, "null");
				Dialog.show();
				phenotype = Dialog.getRadioButton();
			}
			
			im = replace(title, ".tif", "");
			out += im + "," + phenotype + "\n";
			
			selectWindow("random image");
			getMinAndMax(min, max); // preserve display range for the next image
			close();
		}	
	}
	File.saveString(out, dir + "phenotypes.csv");
}

macro "regionMeasure [i]" {
/*
Given a rectangular or oval area, measure mean area intensity over a stack.

Input
=====

Rectangular or oval selection on open stack.

Output
======

A .csv file inside a '/measurements/' folder within the working
directory.
An overlay of the selection with x, y, height and width coordinates spelled out.
*/

	check4ROItype(0, 1, -1); //rectangular or oval seletion required
	
  setBatchMode("hide");
	im = getTitle();
	dir = getDirectory("image");
	
	// create output folder
  dir_out = dir + "measurements" + File.separator;
	if (!File.exists(dir_out)) {
		File.makeDirectory(dir_out);
	}
  
  // get variables to remember selection
	length = nSlices();
	type = selectionType();
  getSelectionBounds(x, y, width, height);

  // make sure we start with a clean slate
	run("Set Measurements...", "mean redirect=None decimal=3");
	run("Clear Results");
  run("Select None");
	
  // loop measurement over all slices
	for(l = 1; l < length + 1; l++) {
	  setSlice(l);
    run("Restore Selection");
		run("Measure");
	}

	csv = replace(im, ".tif", "_x" + x + "y" + y + "w" + width + "h"
                  + height + ".csv");
  saveAs("Results", dir_out + csv);
	
  // attach an overlay to make note of region
  setFont("SanSerif", 18, "antialiased");
	setColor("white");
  if (type == 0) {
    Overlay.drawRect(x, y, width, height);
  } else {
      Overlay.drawEllipse(x, y, width, height)
  };

	Overlay.drawString("x" + x + "y" + y + "w" + width + "h" + height, x, y);
	Overlay.show();

	saveAs("Tiff", dir + im);
	setBatchMode("show");
}

macro "particle_tracker_batch" {
/*
Experimental: get batch ParticleTracker output (to later analyse with TrajPlot).

Input
=====

Folder of all .tif images to be analysed.
ParticleTracker parameters (see their docs).

Output
======

ParticleTracker report files.
*/

	in = getDirectory("Choose input Directory");

	Dialog.create("ParticleTracker parameters");
	Dialog.addNumber("Radius", 3);
	Dialog.addNumber("Cut-off", 0.1);
	Dialog.addNumber("Percentile", 0.5);
	Dialog.addNumber("Linking range", 2);
	Dialog.addNumber("Displacement", 1);
	Dialog.show();
	rad = Dialog.getNumber();
	cut = Dialog.getNumber();
	per = Dialog.getNumber();
	lin = Dialog.getNumber();
	dis = Dialog.getNumber();
	
	list = getFileList(in);
	
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			im = list[i];
			open(in + im);
			rename(replace(im, ".tif", ""));
			run("Particle Tracker 2D/3D", "radius=" + rad + " cutoff=" + cut
				+ " per/abs=" + per + " link=" + lin + " displacement=" + dis
				+ " dynamics=Brownian");
			close();
		}
	}
	setBatchMode(false);
}

macro "cyto_spot_measure"{
/*
Experimental: measure intensities of spots, cytosol and background across stack.
Based entirely on median-filter thresholding.

Input
=====

Open image.
Parameters are hardcoded at the moment.

Output
======

Folder 'cyto_measure' with .csv files for each filename and region combination.
*/

	name = getTitle();
  dir = getDirectory("image");
	out = dir + "cyto_measure" + File.separator;
	File.makeDirectory(out);
  
  cell = replace(name, ".tif", "_cell.tif");
  spots = replace(name, ".tif", "_spots.tif");
  cyto = replace(name, ".tif", "_cyto.tif");
  bg = replace(name, ".tif", "_bg.csv");
	
  run("Duplicate...", "title=" + cell + " duplicate");
	run("Median...", "radius=" + 20 + " stack");

	imageCalculator("Subtract create stack", name, cell);
	selectWindow("Result of "+ name);
  rename(spots);

  selectWindow(cell);
  run("Auto Threshold", "method=Triangle white stack");
  saveAs("Tiff", out + cell);

  selectWindow(spots);
  run("Auto Threshold", "method=Triangle white stack");
  run("Erode", "stack");
  run("Dilate", "stack");
  run("Dilate", "stack");
  saveAs("Tiff", out + spots);

	imageCalculator("Subtract create stack", cell, spots);
	selectWindow("Result of "+ cell);
  rename("cyto");
  saveAs("Tiff", out + cyto);

  setBatchMode(true);
  selectWindow(cell);
	setSlice(1);
  run("Select None");
  selectWindow(name);
	setSlice(1);
  run("Select None");
  
	run("Set Measurements...", "mean redirect=None decimal=9");
	run("Clear Results");
	
	for(l=0; l < nSlices + 1; l++) {
    selectWindow(cell);
    run("Create Selection");
		run("Next Slice [>]");

    selectWindow(name);
		run("Restore Selection");
		run("Measure");
		run("Next Slice [>]");
	}
  saveAs("Results", out + replace(cell, ".tif", ".csv"));

  selectWindow(cyto);
	setSlice(1);
  run("Select None");
  selectWindow(name);
	setSlice(1);
  run("Select None");
  
	run("Set Measurements...", "mean redirect=None decimal=9");
	run("Clear Results");
	
	for(l=0; l < nSlices + 1; l++) {
    selectWindow(cyto);
    run("Create Selection");
		run("Next Slice [>]");

    selectWindow(name);
		run("Restore Selection");
		run("Measure");
		run("Next Slice [>]");
	}
  saveAs("Results", out + replace(cyto, ".tif", ".csv"));

  selectWindow(spots);
	setSlice(1);
  run("Select None");
  selectWindow(name);
	setSlice(1);
  run("Select None");
  
	run("Set Measurements...", "mean redirect=None decimal=9");
	run("Clear Results");
	
	for(l=0; l < nSlices + 1; l++) {
    selectWindow(spots);
    run("Create Selection");
		run("Next Slice [>]");

    selectWindow(name);
		run("Restore Selection");
		run("Measure");
		run("Next Slice [>]");
	}
  saveAs("Results", out + replace(spots, ".tif", ".csv"));

  selectWindow(cell);
	setSlice(1);
  run("Select None");
  selectWindow(name);
	setSlice(1);
  run("Select None");
  
	run("Set Measurements...", "mean redirect=None decimal=9");
	run("Clear Results");
	
	for(l=0; l < nSlices + 1; l++) {
    selectWindow(cell);
    run("Create Selection");
    run("Make Inverse");
		run("Next Slice [>]");

    selectWindow(name);
		run("Restore Selection");
		run("Measure");
		run("Next Slice [>]");
	}
  saveAs("Results", out + bg);

  setBatchMode(false);
}

/*
################################################
### Background subtraction and normalization ###
################################################
*/

macro "bleachCorrect"{
/*
Correct the open image for photobleaching, original EMBL macro.
Superseded by the bgSubNorm function.

Input: open image, region to be used as reference for correction.

Output: photobleaching corrected image.
*/

	requires("1.48h");
	check4pic();
	pic2stack();
	if (selectionType()==-1) run("Select All");
	check4ROItype(0,9,-1);

	run("Set Slice...", "slice="+1);
	run("Set Measurements...", "mean redirect=None decimal=9");
//	run("Select None");
	setBatchMode("hide");
	
	for(l=0; l<nSlices+1; l++) {
		run("Restore Selection");
		run("Clear Results");
		run("Measure");
		picsum=getResult("Mean",0);

		if(l==0){
			picsum1=picsum;
		}

		int_ratio=picsum1/picsum;
		//print(int_ratio+' '+picsum1+' '+picsum);
		run("Select None");
		run("Multiply...", "slice value="+int_ratio);
		run("Next Slice [>]");
	} 
	setBatchMode("show");
}

macro "bgSubNorm" {
/*
Invokes the bgSubNorm function to perform rolling ball background subtraction
(hardcoded to 80px radius) and photobleaching correction.

Input: open image, method to generate reference mask, output folder.

Output: photobleaching corrected image saved in output folder.
*/

	FP = getTitle();
	dir = getDirectory("Choose a Directory");

	methodList = getList("threshold.methods");
	Dialog.create("AutoThreshold")
	Dialog.addChoice("Choose a thresholding method:", methodList, "Li");
	Dialog.show();
	method = Dialog.getChoice();

	selectWindow(FP);
	bgSubNorm(80, method);
	bgnorm = replace(FP, ".tif", "_BN.tif");
	saveAs("Tiff", dir + bgnorm);
}

macro "bgSub_batch" {
/*
Perform a rolling ball subtraction on a folder of images.

Input
=====

Folder of .tif images (must have 'FP' in the name to be processed).
Rolling ball radius (default is 80).
Output folder.

Output
======

Background subtracted images saved with '_BS' suffix in the output folder.
*/

	in = getDirectory("Choose input Directory");
	out = getDirectory("Choose output Directory");
	
	Dialog.create("Rolling ball radius");
	Dialog.addNumber("Rolling ball radius:" 80);
	Dialog.show();
	radius = Dialog.getNumber();

	list = getFileList(in);
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			open(in+list[i]);
			FP=getTitle();
			run("Subtract Background...", "rolling="+radius+" stack");
			bgsub=replace(FP, ".tif", "_BS.tif");
			saveAs("Tiff", out + bgsub);
			close();
		}
	}
	setBatchMode(false);
}

macro "bgSubNorm_batch" {
/*
Perform a rolling ball subtraction and photobleaching correction on a folder of images.
Rolling ball radius is hardcoded at 80.

Input
=====

Folder of .tif images (must have 'FP' in the name to be processed).
Thresholding method: check on your images, Li works well for me.
Output folder.


Output
======

Background subtracted images saved with '_BN' suffix in the output folder.
Masks used for generating the reference.
*/

	in = getDirectory("Choose input Directory");
	out = getDirectory("Choose output Directory");


	method_list = getList("threshold.methods");
	Dialog.create("bgSubNorm settings");
	Dialog.addChoice("Choose a thresholding method:", method_list, "Li");
	Dialog.addNumber("Rolling ball radius:" 80);
	Dialog.show();
	method = Dialog.getChoice();
	radius = Dialog.getNumber();

	list = getFileList(in);
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			open(in+list[i]);
			FP = getTitle();
			bgSubNorm(radius, method);
			bgnorm = replace(FP, ".tif", "_BN.tif");
			saveAs("Tiff", out + bgnorm);
			close();
		}
	}
	setBatchMode(false);
}

macro "bgSubNormRed_batch" {
/*
Perform a rolling ball subtraction and photobleaching correction on a folder of images.
Rolling ball radius is hardcoded at 80.
Green images are corrected and mask is generated based on red channel.

Input
=====

Folder of .tif images ('GFP' to be processed, 'RFP' to generate mask).
Thresholding method: check on your images, Li works well for me.
Output folder.


Output
======

Background subtracted images saved with '_BN' suffix in the output folder.
Masks used for generating the reference.
*/

	in = getDirectory("Choose input Directory");
	out = getDirectory("Choose output Directory");

	method_list = getList("threshold.methods");
	Dialog.create("bgSubNorm settings");
	Dialog.addChoice("Choose a thresholding method:", method_list, "Li");
	Dialog.addNumber("Rolling ball radius:" 80);
	Dialog.show();
	method = Dialog.getChoice();
	radius = Dialog.getNumber();

  list = getFileList(in);
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"GFP")!=-1)) {
			open(in+list[i]);
			im = getTitle();
			bgSubNormRed(radius, method);
			im_norm = replace(im, ".tif", "_BN.tif");
			saveAs("Tiff", out + im_norm);
			close();
		}
	}
}

macro "subtractMedian" {
/*
Invokes the medianFilter function with default arguments.

Input: open image.

Output: open image minus median-filtered image.
*/

	name = getTitle();
	subtractMedian(6);
	selectWindow("Result of "+ name);
	md_name = replace(name,".tif","_MD.tif");
	rename(md_name);
}

macro "subtractMedian_batch" {
/*
Process a folder of images to subtract a median-filtered image.

Input: folder of .tif images (must have 'FP' in the name), median filter radius.

Output: new folder of .tif images with '_MD' suffix.
*/

	in = getDirectory("Choose input Directory");
	
	Dialog.create("Median filter radius");
	Dialog.addNumber("Median filter radius:" 6);
	Dialog.show();
	radius = Dialog.getNumber();
	
	out = in + "MD" + File.separator;
	File.makeDirectory(out);
	
	list = getFileList(in);
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			open(in+list[i]);
			FP=getTitle();
			subtractMedian(radius);
			md_name=replace(FP, ".tif", "_MD.tif");
			saveAs("Tiff", out + md_name);
			close();
		}
	}
}

/*
############################
### Selections and crops ###
############################
*/

/*
Group of macros to make selections of given size.
*/

macro "makeSquare100 [q]" {
	makeRectangle(1, 1, 100, 100);
}

macro "makeSquare200 [w]" {
	makeRectangle(1, 1, 150, 150);
}

macro "makeSquare300 [e]" {
	makeRectangle(1, 1, 200, 200);
}

macro "makeSquare40 [t]" {
	makeRectangle(1, 1, 40, 40);
}

macro "makeOval4 [r]" {
	makeRectangle(1, 1, 4, 4);
}

macro "thresholdSelection" {
/*
I have no idea what this is for, candidate for deletion.
*/

	methodList = getList("threshold.methods");
	Dialog.create("AutoThreshold")
	Dialog.addChoice("Choose a thresholding method:", methodList, "Li");
	Dialog.show();
	method = Dialog.getChoice() //+" white";
	
	FP = getTitle();
	
	run("Select None");
	run("Duplicate...", "duplicate title=mask.tif");
	run("Auto Threshold", "method=" + method + " white");
	run("Convert to Mask");
	run("Create Selection");
	close();

	selectWindow(FP);
	run("Restore Selection");
}

macro "saveCropped [u]"{
/*
Save current selection as a .tif file with '_crop' suffix in current folder.
*/

	requires("1.33n");
	dir = getDirectory("image");
	Title = getTitle();
	selectWindow(Title);
	ImageNameShort = substring(Title,0,lengthOf(Title)-4);
	run("Select None");
	run("Restore Selection");
	run("Crop");
	saveAs("Tiff", dir + ImageNameShort + "_crop.tif");
}

macro "saveRegion8b [U]" {
/*
Save current selection as an 8-bit .tif file in the current folder.

Assumes that the image is a stack and saves the current slice only.
Performs 8-bit conversion using the full dynamic range. 
*/

	dir = getDirectory("image");
	im = getTitle();
	getSelectionBounds(x, y, width, height)
	slice = getSliceNumber();
	
	im_crop = replace(im, ".tif", "x" + x + "y" + y + "h" + height + "w" + width + "slice" + slice + "_8b.tif");
	run("Duplicate...", "title=crop range=" + slice + "-" + slice);
	resetMinAndMax();
	run("8-bit");
	saveAs("Tiff", dir + im_crop);
}

macro "saveSlice [S]" {
/*
Save t or z slice from an open stack as a .tif file in the current folder.
*/

	dir = getDirectory("image")
	title = getTitle();
	slice = getSliceNumber();
	run("Duplicate...", "duplicate range=" + slice + "-" + slice);
	saveAs("Tiff", dir + replace(title, ".tif", "_Slice" + slice + ".tif"));
}

macro "saveCell [1]"{
/*
Save current selection as a .tif.

Asks for cell number and adds an overlay with the selection and number.
Includes a 'Cell' suffix and the number in the filename.
*/

	dir_in = getDirectory("image");
	im_in = getTitle();

  dir_out = dir_in + "cells" + File.separator;
	if (!File.exists(dir_out)) {
		File.makeDirectory(dir_out);
	}

	number = getString("Which cell?", "01");
	selectWindow(im_in);

 // this part adds cell number plus selection as overlay
	getSelectionBounds(x, y, w, h);
	setLineWidth(2);
	setFont("SanSerif", 18, "antialiased");
	setColor("white");
	Overlay.drawRect(x, y, w, h);
	Overlay.drawString(number, x, y);
	Overlay.show();

	run("Duplicate...", "duplicate");
	Overlay.remove();

	// worst-case scanario: no channel, Cell# goes before extension
  im_out = replace(im_in, ".tif", "_Cell" + number + ".tif");

  // if there's a usual channnel, Cell# goes before the channel
  channels = newArray("BF", "GFP", "RFP");
	for (i = 0; i < channels.length; i++) {
		if (indexOf(im_in, channels[i]) > -1){
	    im_out = replace(im_in, channels[i], "Cell" + number + "_" + channels[i]);
      break();
		}
	}

	saveAs("Tiff", dir_out + im_out);
	close();

	selectWindow(im_in);
	saveAs("Tiff", dir_in + im_in);
}

function cropColor(to, number) {
/*
A function to crop cells out of multi-channel images.
Understands three channels ('BF', 'GFP', 'RFP').
Detects which of the three is currently open, and opens files
which are named identically except for different channel and, optionally, suffix.
It can understand that *FP channels can have custom suffixes from processing
which come *after* the identical root,
like 'BS' or 'BN' or a custom suffix entered via a dialogue window.

e.g. if 'pretty_yeast_BF.tif' is open, the function can open
'pretty_yeast_GFP.tif', 
'pretty_yeast_RFP.tif', 
'pretty_yeast_GFP_BS.tif',
'pretty_yeast_RFP_mysuffix.tif' et cetera,
but *not* 'pretty_yeast_2_GFP.tif'.

Input
=====

to: array of strings (which channels to crop besides the open one)
number: cell number
*/

	im_in = getTitle();
	dir_in = getDirectory("image")
	dir_out = dir_in + "cells" + File.separator;
	if (!File.exists(dir_out)) {
		File.makeDirectory(dir_out);
	}

	channels = newArray("BF", "GFP", "RFP");
	for (i = 0; i < channels.length; i++) {
		if (indexOf(im_in, channels[i]) > -1){
			from = channels [i];
		}
	}

	for (i = 0; i < to.length; i++){
		im_color = replace(im_in, from, to[i]);
		
		// if there is no file, check if background subtracted exists
		if (!File.exists(dir_in + im_color)){
			im_color = replace(im_in, from, to[i] + "_BS");
			// if still no file, check normalized
			if (!File.exists(dir_in + im_color)){
				im_color = replace(im_in, from, to[i] + "_BN");
			}
			// if still no file, bother the user
			while(!File.exists(dir_in + im_color)){
				process = getString(
					"Cannot find your file. Enter custom suffix:", "");
				im_color = replace(im_in, from, to[i] + "_" + process);
			}
		}

    if (!isOpen(im_color)){
      open(dir_in + im_color);
    }

    selectWindow(im_color);
		run("Restore Selection");
		run("Duplicate...", "duplicate");
		im_out = replace(im_color, to[i], "Cell" + number + "_" + to[i]);
		saveAs("tiff", dir_out + im_out);
		close();
    selectWindow(im_in);
  }
	
	getSelectionBounds(x, y, w, h);
	setLineWidth(2);
	setFont("SanSerif", 18, "antialiased");
	setColor("white");
	Overlay.drawRect(x, y, w, h);
	Overlay.drawString(number, x, y);
	Overlay.show();

	run("Duplicate...", "duplicate");
	Overlay.remove;
	im_out = replace(im_in, from, "Cell" + number + "_" + from);
	saveAs("Tiff", dir_out + im_out);
	close();
	selectWindow(im_in);
	save(dir_in + im_in);
}

macro "cropCellGFP [2]" {
/*
Application of the cropColor() function.

Crops cell out of the current file with 'BF', or 'RFP' in the name,
and a file of the same name with 'GFP' substituted for channel.
*/

	to = newArray("GFP")
	number = getString("Which cell?", "01");
	setBatchMode("hide");
	cropColor(to, number);
	setBatchMode("exit and display");
}

macro "cropCellRFP [3]" {
/*
Application of the cropColor() function.

Crops cell out of the current file with 'BF', or 'GFP' in the name,
and a file of the same name with 'RFP' substituted for channel.
*/

	to = newArray("RFP")
	number = getString("Which cell?", "01");
	setBatchMode("hide");
	cropColor(to, number);
	setBatchMode("exit and display");
}

macro "cropCell2color [4]" {
/*
Application of the cropColor() function.

Crops cell out of the current file with 'BF' in the name,
and two files of the same name with 'GFP' and 'RFP' substituted for 'BF'.
*/

	to = newArray("GFP", "RFP");
	number = getString("Which cell?", "01");
	setBatchMode("hide");
	cropColor(to, number);
	setBatchMode("exit and display");
}

/*
##########################################
### Stack conversions and color merges ###
##########################################
*/

macro "saveZmax [Z]" {
/*
Save a maximum Z-projection of the open stack with '_MAX' suffix.
*/

	dir = getDirectory("image")
	title = getTitle();
	run("Z Project...", "start=1 stop="+nSlices()+" projection=[Max Intensity]");
	saveAs("Tiff", dir + replace(title, ".tif", "_MAX.tif"));
}

macro "saveZmax_batch" {
/*
Save maximum Z-projections of all images in a folder inside a 'maxZ' subfolder.

Input: folder to process.
*/

	in = getDirectory("Choose input Directory");
	out = in + "maxZ" + File.separator;
	File.makeDirectory(out);
	list = getFileList(in);
	
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			open(in+list[i]);
			name = getTitle();
			run("Z Project...", "start=1 stop="+nSlices()+" projection=[Max Intensity]");
			max_name = replace(name, ".tif", "_MAX.tif");
			saveAs("Tiff", out + max_name);
			close();
		}
	}
}

macro "saveZavg_batch" {
/*
Save average Z-projections of all images in a folder inside a 'avgZ' subfolder.

Input: folder to process.
*/

	in = getDirectory("Choose input Directory");
	out = in + "avgZ" + File.separator;
	File.makeDirectory(out);
	list = getFileList(in);
	
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			open(in+list[i]);
			name = getTitle();
			run("Z Project...", "start=1 stop="+nSlices()+" projection=[Average Intensity]");
			max_name = replace(name, ".tif", "_AVG.tif");
			saveAs("Tiff", out + max_name);
			close();
		}
	}
}

macro "8bitStack" {
/*
Sonvert stack to 8bit while preserving maximum range.
Invokes max8b() function.
*/

	setBatchMode("hide")
	title = getTitle();
	dir = getDirectory("image");
	title8b = replace(title,".tif","-8b.tif");
	max8b();
	setBatchMode("show");
}

macro "save8bitStack [B]" {
/*
Convert stack to 8bit while preserving maximum range.
Uses max8b() function and saves file.
*/

	setBatchMode("hide");
	title = getTitle();
	dir = getDirectory("image");
	title8b = replace(title,".tif","-8b.tif");
	max8b();
	saveAs("Tiff",dir + title8b);
	setBatchMode("show");
}

macro "save8bitStackAndMerge [j]" {
/*
Convert two color stacks to 8bit while preserving maximum range.
Uses max8b() function, performs a red/green merge and saves file.

Input
=====

Open file with 'GFP' in name
File in the same folder with 'RFP' instead of 'GFP'

Output
======

Two-color 8-bit composite, saved to disk.
*/

	setBatchMode("hide");
	GFP = getTitle();
	dir = getDirectory("image");
	GFP8b = replace(GFP, ".tif", "-8b.tif");
	max8b();

	RFP = replace(GFP, "GFP", "RFP");
	open(dir + RFP);
	RFP8b = replace(RFP, ".tif", "-8b.tif");
	max8b();

	run("Merge Channels...", "c6=" + RFP + " c2=" + GFP + " create");
	merge = replace(GFP8b, "GFP", "Merge");
	saveAs("Tiff", dir + merge);
	setBatchMode("show");
}

macro "combineStacksFromMerge [k]" {
/*
Creates a combined RGB image (or stack) showing green, red and merge channels
side-by-side.

RGB conversion sets the white and black points to the display settings.
Therefore it is advisable to make brightness and contrast adjustments
on the merge (obtained from macro above), then run this macro to get a 
presentation-ready image.

So if you have images with same names differing in RFP/GFP, you can:

1. Open the GFP channel
2. Press 'j' to create composite
3. Adjust constrast/brightness
4. Press 'k' to create side-by-side combined image.

Input
=====

Green/magenta two-color composite (like the one generated by save8bitStackAndMerge).

Output
======

Combined image with left-to-right GFP, RFP and merge, saved to disk.
*/

	setBatchMode("hide");
	dir = getDirectory("image");
	titleMerge = getTitle();
	titleGFP = "C1-" + titleMerge;
	titleRFP = "C2-" + titleMerge;
	run("Duplicate...", "title=RGB duplicate");
	selectWindow("RGB");
	
	// added this section because ImageJ has different commands for RGB conversion of z- and t-stacks
	Stack.getDimensions(width, height, channels, slices, frames);
	if (frames > 1){
		run("RGB Color","frames");
	} else if (slices > 1) {
		run("RGB Color","slices");
	} else {
  // if the image is only one plane, ImageJ duplicates it, then converts it
  // and renames to "name (RGB)". it's a bit silly like that.
		run("RGB Color");
		selectWindow("RGB"); //to close the 8bit window
		close();
		selectWindow("RGB (RGB)"); // to rename the RGB to RGB so that it's the same as if coming from a stack
		rename("RGB");
	}

	length = nSlices();

	selectWindow(titleMerge);
	run("Split Channels");
	
	selectWindow(titleRFP);
	getMinAndMax(min, max);
	run("Grays");
	setMinAndMax(min, max);
	run("RGB Color");
	rename("RFP");
	
	selectWindow(titleGFP);
	getMinAndMax(min, max);
	run("Grays");
	setMinAndMax(min, max);
	run("RGB Color");
	rename("GFP");

	newImage("spacer", "RGB White", 3, height, length);
	newImage("spacer2", "RGB White", 3, height, length);
	
	run("Combine...", "stack1=spacer stack2=RGB");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=RFP stack2=Combi");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=spacer2 stack2=Combi");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=GFP stack2=Combi");
	setBatchMode("show");

	titleCombined = replace(titleMerge, "Merge", "Combined");
	titleCombined = replace(titleCombined, "8b", "RGB");
	saveAs("Tiff", dir + titleCombined);
}

macro "regionCombine [y]" {
/*
Crop selected region and create a combined RGB image (or stack)
showing green, red and merge channels side-by-side.

Does not go through a composite and leaves overlay with the region selection.
This macro is very similar to the previous one, but it was quickly written
to check colocalizations; therefore we crop based only on the green channel
and display settings preserve full dynamic range.

Input
=====

Open file with 'GFP' in name.
File in the same folder with 'RFP' instead of 'GFP'.

Output
======

Combined image with left-to-right GFP, RFP and merge, saved to disk.
*/

	check4ROItype(0, 0, -1); //rectangular seletion required
	setBatchMode("hide");
	im_gfp = getTitle();
	dir = getDirectory("image");
	
	dir_out = dir + "combined" + File.separator;
	
	if (!File.exists(dir_out)) {
		File.makeDirectory(dir_out);
	}

	getSelectionBounds(x, y, width, height);
	length = nSlices();

	makeRectangle(x, y, width, height);
	run("Crop");
	resetMinAndMax();

	im_rfp = replace(im_gfp,"GFP","RFP");
	open(dir + im_rfp);
	makeRectangle(x, y, width, height);
	run("Crop");
	resetMinAndMax();

	run("Merge Channels...", "c6=" + im_rfp + " c2=" + im_gfp + " keep");

	selectWindow(im_gfp);
	run("RGB Color"); 
	selectWindow(im_rfp);
	run("RGB Color"); 

	newImage("spacer", "RGB White", 3, height, length);
	newImage("spacer2", "RGB White", 3, height, length);
	
	run("Combine...", "stack1=spacer stack2=RGB");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=" + im_rfp + " stack2=Combi");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=spacer2 stack2=Combi");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=" + im_gfp + " stack2=Combi");

	im_out = replace(im_gfp,"GFP", "RGB");
	im_out = replace(im_out, ".tif", "x" + x + "y" + y + ".tif");
	saveAs("Tiff", dir_out + im_out);

	open(dir + im_gfp);
	setLineWidth(2);
	setFont("SanSerif", 18, "antialiased");
	setColor("white");
	Overlay.drawRect(x, y, width, height);
	Overlay.drawString("x" + x + "y" + y, x, y);
	Overlay.show();

	saveAs("Tiff", dir + im_gfp);

	setBatchMode("show");
	run("Enhance Contrast", "saturated=0.05");
	makeRectangle(x, y, width, height);
}

macro "regionMontage" {
/*
Create a two-color movie montage from a selection
(typically endocytic patch but could be anything really).
Like with combineStacksFromMerge, RGB conversion clips values
so adjust contrast/brightness on the composite before running the macro.

This will be a one-row montage. Pick the range and increment accordingly.

It is possible to scale the picture up or down.
Scaling does *not* interpolate, unlike when doing it through the Montage options.

Input
=====

Selection on open composite movie stack (will most likely fail on Z-stack).
Montage parameters: same as when invoking Montage from ImageJ.

Output
======

A montage with green, red and merge channels.
*/

  Dialog.create("Montage parameters");
	Dialog.addNumber("From frame:" 1);
	Dialog.addNumber("To frame:" 20);
	Dialog.addNumber("By increment of:" 1);
	Dialog.addNumber("Scale image by the factor of:" 1);
	Dialog.addNumber("Border size (px):" 3);
	Dialog.show();

	first = Dialog.getNumber();
	last = Dialog.getNumber();
	by = Dialog.getNumber();
	scale = Dialog.getNumber();
	border = Dialog.getNumber();

	setBatchMode("hide");
	dir = getDirectory("image");
	im_merge = getTitle();
	//im_gfp = "C1-"+ im_merge;
	//im_rfp = "C2-"+ im_merge;
	getSelectionBounds(x, y, width, height)
	run("Duplicate...", "title=RGB duplicate frames=" + first + "-" + last);
	run("Duplicate...", "title=colors duplicate frames=" + first + "-" + last);
	selectWindow("RGB");
	
	// same stack caveat as in the RGB conversion macro could be added
  // I just assume nobody would use it for anything other than timelapses
	// Stack.getDimensions(width, height, channels, slices, frames);
	run("RGB Color", "frames");

	length = nSlices();

	selectWindow("colors");
	Stack.setDisplayMode("grayscale");
	run("Split Channels");
	
	selectWindow("C2-colors");
	run("RGB Color");
	rename("RFP");
	
	selectWindow("C1-colors");
	run("RGB Color");
	rename("GFP");

	newImage("spacer", "RGB White", width, border, length);
	newImage("spacer2", "RGB White", width, border, length);
	
	run("Combine...", "stack1=spacer stack2=RGB combine");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=RFP stack2=Combi combine");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=spacer2 stack2=Combi combine");
	selectWindow("Combined Stacks");
	rename("Combi");
	run("Combine...", "stack1=GFP stack2=Combi combine");
	
	// thus ends combining macro, now for the montage
	columns = 1 + floor((length - 1) / by);
  run("Colors...", "foreground=white");
	run("Make Montage...", "columns=" + columns +
    " rows=1 scale=1 first=1 last=" + length + " increment=" + by +
    " border=" + border + " font=12 use");

	// 'Make Montage...' actually runs scaling with interpolation so it's important to scale after
	if (scale != 1) {
		run("Scale...", "x=" + scale + " y=" + scale + 
      " interpolation=None average create title=scaled");
	}

	setBatchMode("show");

	im_montage = replace(im_merge, "Merge", "Montage");
	im_montage = replace(im_montage, "8b", "x" + x + "y" + y + "h" + height + 
    "w" + width + "from" + first + "to" + last + "by" + by + "times" + scale);
	saveAs("Tiff", dir + im_montage);
}

/*
#################################
### File and format operations###
#################################
*/

macro "savePlaneTimings" {
/*
Save the plane deltas of active image to file.

Input: open image

Output: .txt file with plane deltas
*/
	
	dir = getDirectory("image");
	im = getTitle();
	run("Bio-Formats Macro Extensions");
	
	times = planeTimings(dir + im);

	File.saveString(times, dir + substring(im, 0, lengthOf(im) - 4) + "_times.txt");
}

macro "savePlaneTimings_batch" {
/*
Save the plane deltas of all images in folder to file.

Input: folder with images. Images need to have 'FP' in the name.

Output: .txt files with plane deltas
*/

	dir = getDirectory("Choose data directory");
	list = getFileList(dir);
	run("Bio-Formats Macro Extensions");
	setBatchMode(true);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			times = planeTimings(dir + list[i]);
			File.saveString(times, dir + replace(list[i],".tif", "_times.txt"));
		}
	}
	setBatchMode(false);
}

macro "removeOverlays_batch" {
/*
Remove overlays from all images in folder.

Input: folder with .tif images.
*/

	dir = getDirectory("Choose data directory");
	list = getFileList(dir);
	
	setBatchMode(true);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], ".tif")) {
			open(dir+list[i]); 
			title=getTitle();
			Overlay.remove;
			saveAs("Tiff", dir + title);
			close();
		}
	}
	setBatchMode(false);
}

macro "2fpCrop_batch" {
/*
Crop Gemini two-color images based on a *manual* specification of green / red areas.

Writes a .tif image for each channel, and one for a green / magenta merge.

Input
=====

Folder with .tif images. Images to be processed need to contain '2FP' in filename.
Width, height: Size of window used for each channel.
x, y: Positions of upper left corner of each channel window.
*/

	in = getDirectory("Choose input Directory");

	Dialog.create("GFP/RFP crop areas");
	Dialog.addNumber("Width:" 510);
	Dialog.addNumber("Height:" 240);
	Dialog.addNumber("RFP x:" 1);
	Dialog.addNumber("RFP y:" 5);
	Dialog.addNumber("GFP x:" 1);
	Dialog.addNumber("GFP y:" 265);
	Dialog.show();

	width = Dialog.getNumber();
	height = Dialog.getNumber();
	xRFP = Dialog.getNumber();
	yRFP = Dialog.getNumber();
	xGFP= Dialog.getNumber();
	yGFP= Dialog.getNumber();

	parString = "w" + width + "h" + height + "_RFPx" + xRFP + "y" + yRFP + "_GFPx" + xGFP + "y" + yGFP;
	out = in + parString + File.separator;
	outMerged = out + "merged" + File.separator;
	File.makeDirectory(out);
	File.makeDirectory(outMerged);

	list = getFileList(in);
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
//		setBatchMode(true);
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"2FP")!=-1)) {
			open(in+list[i]);
			title2fp = getTitle();
			titleRFP = replace(title2fp, "2FP", "RFP");
			titleGFP = replace(title2fp, "2FP", "GFP");
			titleMerge = replace(title2fp, "2FP", "Merge");
			
			makeRectangle(xRFP, yRFP, width, height);
			run("Duplicate...", "duplicate");
			saveAs("Tiff", out + titleRFP);

			selectWindow(title2fp);
			makeRectangle(xGFP, yGFP, width, height);
			run("Duplicate...", "duplicate");
			saveAs("Tiff", out + titleGFP);

			run("Merge Channels...", "c6="+titleRFP+" c2="+titleGFP+" create");
//			selectWindow("Merged");
			saveAs("Tiff", outMerged + titleMerge);
			close();
			selectWindow(title2fp);
			close();
		}
		else if (endsWith(list[i], ".tif") && (indexOf(list[i],"BF")!=-1)) {
			open(in+list[i]);
			titleBF = getTitle();
			makeRectangle(xGFP, yGFP, width, height);
			run("Crop");
			saveAs("Tiff", out + titleBF);
			close();
		}
	}
	setBatchMode(false)
}

macro "stack2color_batch" {
/*
I think this was written to convert 2 / 3 color CLEM images
saved as 2 / 3 slice stacks. Might be wrong though. Keep for now.

Input
=====

Output
======

*/

	in = getDirectory("Choose input Directory");
//	out = getDirectory("Choose output Directory");
	out = in + "composites" + File.separator;
	File.makeDirectory(out);
	list = getFileList(in);
	
	setBatchMode(true);
	for (i=0; i<(list.length); i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)) {
			open(in+list[i]);
			name = getTitle();
			colors = nSlices();
			run("Stack to Images");
			
			red = replace(name, ".tif", "-0001");
			green = replace(name, ".tif", "-0002");

			if (colors == 2) {
				run("Merge Channels...", "c1=" + red + " c2=" + green + " create");
				saveAs("Tiff", out + name);
				close();
			}
			
			if (colors == 3) { 
				blue = replace(name, ".tif", "-0003");
				run("Merge Channels...", "c1=" + red + " c2=" + green + " c3=" + blue + " create");
				saveAs("Tiff", out + name);
				close();
			}
		}
	}
}



/*
########################
### Just FRAP things ###
########################
*/

macro "measureFRAPautoThreshold [Q]" {
/*
For quantifying FRAP experiments.
Measure 3 ROIs from timelapse: spot, cell and background.
The spot (bleach) region is selected manually and the macro attempts to
guess the cell and background by thresholding.
I cannot bring myself to delete this macro, but I do not recomment using it.

Input
=====

Oval selection of bleached region in a timelapse.
Thesholding method.

Output
======
Three files containing intensity measurements with _patch.txt,
_background.txt or _cell.txt in place of .tif extension.
*/
	check4stack();
	check4ROItype(1,1,-1);

	dir = getDirectory("Choose output directory");
	title = getTitle();

	run("Auto Threshold", "method=[Try all] white");
	methodList = getList("threshold.methods");
	Dialog.create("AutoThreshold")
	Dialog.addChoice("Choose a thresholding method:", methodList, "Li");
	Dialog.show();
	method = Dialog.getChoice();
	selectWindow(title);

	cell = replace(title, ".tif", "_cell.txt");
	background = replace(title, ".tif", "_background.txt");
	patch = replace(title, ".tif", "_patch.txt");

	run("Set Measurements...", "mean redirect=None decimal=9");
	setBatchMode(true);

	setSlice(1);
	for(f=0; f<nSlices(); f++) {
		run("Measure");
		run("Next Slice [>]");
	}

	selectWindow("Results");
	saveAs("Results", dir + patch);
	run("Clear Results");
	
	setOption("BlackBackground", true);

	selectWindow(title);
	run("Select None");

	run("Duplicate...", "title=cellmask duplicate range=1-1");
	run("Auto Threshold", "method=" + method + " white");
	run("Open");
	run("Fill Holes");
	run("Convert to Mask");
	run("Create Selection");
	
	selectWindow(title);
	setSlice(1);

	run("Restore Selection");

	for(f=0; f<nSlices(); f++) {
		run("Measure");
		run("Next Slice [>]");
	}

	selectWindow("Results");
	saveAs("Results", dir + cell);
	run("Clear Results");
	
	selectWindow("cellmask");
	run("Select None");
	run("Fill Holes");
	run("Create Selection");

	selectWindow(title);
	setSlice(1);

	run("Restore Selection");
	run("Make Inverse");
	
	for(f=0; f<nSlices(); f++) {
		run("Measure");
		run("Next Slice [>]");
	}
	
	selectWindow("Results");
	saveAs("Results", dir + background);
	run("Clear Results");

	run("Close All"); 

	setOption("BlackBackground", false);
	setBatchMode(false);
}

macro "batchMeasureFRAPmanual" {
/*
For quantifying FRAP experiments.
Measure 3 ROIs from timelapse: patch (photobleached region),
cell (entire fluorescent structure) and background (outside of cell).
Process entire folder of timelapse images.

Input
=====

Folder containing timelapse images.
Manual ROI selections.

Output
======
Three files containing intensity measurements with _patch.txt,
_background.txt or _cell.txt in place of .tif extension for each image in folder.

ROIs saved as a .zip file.
*/
	dir=getDirectory("Choose data directory");
	out=getDirectory("Choose output directory");
	list=getFileList(dir);

	run("Set Measurements...", "mean redirect=None decimal=9");

	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], ".tif") && (indexOf(list[i],"FP")!=-1)){
			open(dir + list[i]);
			
			close("\\Others");
			run("Select None");
			setSlice(1);

			Title = getTitle();
		
// Set filenames to save results

			cell = replace(Title, ".tif", "_cell.txt");
			background = replace(Title, ".tif", "_background.txt");
			patch = replace(Title, ".tif", "_patch.txt");
			roi = replace(Title, ".tif", "_roi.zip");
			run("ROI Manager...");

// Measure patch	
			waitForUser("Select a suitable patch ROI and click OK");
		
			roiManager("Add");
			
			setBatchMode(true);
			setSlice(1);
			run("Clear Results");
			for(f=0; f<nSlices(); f++) {
				run("Measure");
				run("Next Slice [>]");
			}

			selectWindow("Results");
			saveAs("Results", out + patch);

			setSlice(1);
			setBatchMode(false);
// Measure cell
			waitForUser("Select a suitable cytoplasmic ROI and click OK");
		
			roiManager("Add");
			
			setBatchMode(true);
			setSlice(1);
			run("Clear Results");
			for(f=0; f<nSlices(); f++) {
				run("Measure");
				run("Next Slice [>]");
			}

			selectWindow("Results");
			saveAs("Results", out + cell);

			setSlice(1);
			setBatchMode(false);
// Measure background
			waitForUser("Select a suitable background ROI and click OK");
		
			roiManager("Add");
			
			setBatchMode(true);
			setSlice(1);
			run("Clear Results");
			for(f=0; f<nSlices(); f++) {
				run("Measure");
				run("Next Slice [>]");
			}

			selectWindow("Results");
			saveAs("Results", out + background);

			setSlice(1);
			setBatchMode(false);

			roiManager("Save", out + roi);
			roiManager("Delete");
		} //close if clause
	} //close for loop
}
 
macro "measureCentroidsOnClick" {
/*
Measure patch values around points selected with the multipoint tool.
Written specifically to read the data from two-color TIRF.

Assumes round patches with a radius of 3 px.
Does not correct for chromatic avberrations or anything fancy like that.

In some ways, it is actually a primitive particle tracker.
Once user makes the selection (ideally at a time right before bleach) close
to a spot, the algorithm will detect the center of mass of that spot.
For each frame, the spot location will be re-centred on the center of mass,
and mean intensity of the spot will be saved.
The operation will be repeated in the RFP channel, but locations are based
on GFP.

Input
=====

Open image with 'GFP' in the name.
File in the same folder with 'RFP' instead of 'GFP'.
Multipoint selection of bleached patches
(all at once, preferably at a time before bleach).

Output
======

Measurement of mean spot intensity at a given time.
.zip files with ROIs (can be loaded by ROI manager).
*/
	gfp = getTitle();
	rfp = replace(gfp, "GFP", "RFP");
	roi = replace(gfp, ".tif", "_roi.zip");
	dir = getDirectory("image");
	out = dir + "patchValues" + File.separator;
	File.makeDirectory(out);
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixel");
	run("Select None");
	setTool("multipoint");
	waitForUser("Please select center points for all areas of interest. Click OK when done")
	run("Clear Results");
	roiManager("reset");
	roiManager("Add");
	roiManager("Measure");
	px = newArray();
	py = newArray();
	pz = newArray();

	for (i=0; i<nResults; i++) {
		px = Array.concat(px, getResult("X", i));
		py = Array.concat(py, getResult("Y", i));
		pz = Array.concat(pz, getResult("Slice", i));
	}
	
	setBatchMode("hide");

	open(dir + rfp);
	selectWindow(gfp);

	for (i=0; i<px.length; i++) {

		patch = indexify(i+1, 2, 0); // converts 1 to '01' and so on
		patch_gfp = replace(gfp, ".tif", "_patch" + patch + ".txt");
		patch_rfp = replace(rfp, ".tif", "_patch" + patch + ".txt");
//		print(px[i]);
	
		setSlice(pz[i]);
		makeOval(px[i] - 3, py[i] - 3, 6, 6);
		run("Clear Results");
		run("Set Measurements...", "center redirect=None decimal=9");
		run("Measure");
		ox = getResult("XM");
		oy = getResult("YM");
	
	// keep finding centers of mass and making circles until the results stop changing
		do {
			ox2 = ox;
			oy2 = oy;
			makeOval(ox - 3, oy - 3, 6, 6);
			run("Clear Results");
			run("Measure");
			ox = getResult("XM");
			oy = getResult("YM");
		} while (abs(ox - ox2) > 0.01 || abs(oy - oy2) > 0.01);
	
	// measure centers of selection in individual frames
		run("Clear Results");
		oxArray = newArray();
		oyArray = newArray();
		setSlice(1);
		for(f=0; f<nSlices(); f++) {
			makeOval(ox - 3, oy - 3, 6, 6);
			run("Measure");
			oxArray = Array.concat(oxArray, getResult("XM"));
			oyArray = Array.concat(oyArray, getResult("YM"));
			run("Next Slice [>]");
		}

	// measure selection in green
		run("Clear Results");
		run("Set Measurements...", "mean redirect=None decimal=9");
		setSlice(1);
	
		for(f=0; f<nSlices(); f++) {
			makeOval(oxArray[f]-3, oyArray[f]-3, 6, 6);
			roiManager("Add");
			run("Measure");
			run("Next Slice [>]");
		}

		selectWindow("Results");
		saveAs("Results", out + patch_gfp);
	
	// measure selection in red
		selectWindow(rfp);
		run("Clear Results");
		setSlice(1);
		
		for(f=0; f<nSlices(); f++) {
			makeOval(oxArray[f]-3, oyArray[f]-3, 6, 6);
			run("Measure");
			run("Next Slice [>]");
		}

		selectWindow("Results");
		saveAs("Results", out + patch_rfp);
		run("Select None");

		selectWindow(gfp);
		run("Select None");
	}
	selectWindow(rfp);
	close();
	roiManager("Save", out + roi);
	setBatchMode("show");
}
