
// --- This code is for measuring measuring 
// nucleus (C1), tag(C2) and target (C3) intensity within nuclear (C1) area

setBatchMode(true);
print("\\Clear");

// --------- Parameters -----------
// 1. file formats
file_format = "nd2";
save_format = "tif";

// 2. selecet chennels for ROI definition (typically C1 with nuclei) and 
// for the target that is going to be saved as a tif file with ROIs
dapi_channel = "C1";

// When images have only two channels, comment this out
tag_channel = "C2";
target_channel = "C3";

// // When images have only two channels, use this line
target_channel = "C2";

ROI_channel = dapi_channel;

// 3. Gaussian blur sigma
gaussian_sigma = 1;

// ------- Actual processing -------

// 1. Direct the user to define the folders for input and output
dataFolder = getDirectory("Choose the folder you want to process");
// outputFolder = getDirectory("Choose the folder you want to store");

// 2. Start analysis
analyzeImageInFolder();

// 3. Let you know the end of analysis for all data
print('Finshed all analysis');

// --------- Functions -------------
// ----- Top-level functions-----
function analyzeImageInFolder() {
	// Function for analyzing the files in the folder
	
	// 1. Get the list of the files
	filelist=getFileList(dataFolder);

	// 2. Analyze indiviual files
	for (i = 0; i < lengthOf(filelist); i++) {
		file=filelist[i];
		if (endsWith(file, file_format)) {
			// process and image analysis - see the function below
			print("About to analyze: " + file);
			processImage();
			print("Finished analyzing: " + file);
		}
	}
}

// ----- Second-level functions-----
function processImage() { 
	// function to anaylyze an given image file
	
	// 1. open the file
	open(file);

	// 2. Process image
	// 2-1. Max project and split channels
	maxProject_then_splitChannels();
	
	// 2-2. Create segmentation from C1 image and make ROIs by StarDist
	createSegmentation_StarDist();
	
	// 2-3. Measure C1, C2 and C3 within ROI and shape descriptors of ROI and save the results to CSV and images with ROI displayed
	measure_tag_and_target();

	// 3. Close the images
	run("Close All");

}

// ----- Third-level functions-----
function maxProject_then_splitChannels() { 
	// For a stack of images, max project and split channels to C1,C2,,,
	
	// 1. Get the number of channels
	getDimensions(width, height, channels, slices, frames);
	number_of_channels = channels;
	
	// 2. Max intesity Z project
	run("Z Project...", "projection=[Max Intensity]");
	maxProjectedImage = getTitle();
	
	// 3. Split and rename each image to C1,C2,,,
	selectWindow(maxProjectedImage);
	run("Split Channels");
	for (i = 1; i < number_of_channels+1; i++) {
		selectWindow("C" + i + "-" + maxProjectedImage);
		rename("C" + i);
		run("Grays");
	}
}

function createSegmentation_StarDist() { 
	// Make a segmented binary image and ROIs

	// 1. Make a segmented image by StarDist 2D
	// with the default setting
	// with input channel being the dapi channel
	
	// When needed Gaussian blur is performed
//	selectWindow(dapi_channel);
//	run("Gaussian Blur...", "sigma=" + gaussian_sigma);
	
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], \nargs=['input':" + dapi_channel +", 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', 'probThresh':'0.5', 'nmsThresh':'0.4', 'outputType':'Both', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");

}


function measure_tag_and_target() { 
	// Measure mean intensity of each channel within ROI and ROI shape desriptors
	// Then save them to CSV
	// Finally save image with ROI displayed to tif

	// 1. get means from DAPI using "getMeans" function defined below
	means_dapi = getMeans(dapi_channel);

	// 2. get means from tag
	// When target = C2, comment this out
//	means_tag = getMeans(tag_channel);

	// 3. redirect measurement to target
	run("Set Measurements...", "area mean shape redirect=" + target_channel + " decimal=3");
	
	// 4. measure mean in the target protein in all ROIs and ROI shape descriptors
	roiManager("deselect");
	roiManager("measure");
	
	// 5. add the nucleus channel mean data to the results
	for (i = 0; i < nResults; i++) {
		setResult("DAPI mean", i, means_dapi[i]);
	}

	// 6. add the tag channel mean data to the results
	// When target = C2, comment this out
//	for (i = 0; i < nResults; i++) {
//		setResult("Tag mean", i, means_tag[i]);
//	}
	
	// 7. add the file name to the results table
	for (i = 0; i < nResults; i++) {
		setResult("File name", i, file);
	}

	// 8. Save to CSV
	selectWindow("Results");
	saveAs("Measurements", dataFolder + "Results of " + file + ".csv");

	
	// 9. Save the image with ROI
	saveImageWithROIs(dapi_channel);
	saveImageWithROIs(target_channel);

	// 10. Clear results and ROIs
	run("Clear Results");
	roiManager("deselect");
	roiManager("delete");
}

// ----- Forth-level functions-----
function getMeans(channel) { 
	// Measure the mean of the given channel within ROIs and return the results as an array

	// 1. redirect measurement to the channel
	run("Set Measurements...", "area mean shape redirect=" + channel + " decimal=3");
	
	// 2. measure mean of tag protein in all ROIs
	roiManager("Deselect");
	roiManager("Measure");
	
	// 3. store mean data to an array
	means = newArray(nResults);
	for (i = 0; i < nResults(); i++) {
	   means[i] = getResult("Mean", i);
	}
	
	// 4. clear the results
	run("Clear Results");

	// 5. return the result array
	return means;
}


function saveImageWithROIs(channel) { 
	// show ROIs on target, and save the image
	selectWindow(channel);
	roiManager("Show None");
	roiManager("Show All with labels");
	selectWindow(channel);
	run("Flatten");
	file_wo_format = replace(file, ".nd2", "");
	saveAs(save_format, dataFolder + file_wo_format + "_" + channel);
}
