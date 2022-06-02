
#include "cutils.h"
#include "jpeg_utils.h"

// for jhead
int ShowTags     = FALSE;
int DumpExifMap  = FALSE;
void ErrFatal(char * msg) {}
void ErrNonfatal(char * msg, int a1, int a2) {}
void FileTimeAsString(char * TimeStr) {}

// This procedure is called by the IJPEG library when an error occurs.
static void error_exit (j_common_ptr pcinfo) {
  throw 1;
}

const char* jpegTransform(const char* file, JXFORM_CODE trans) {
	
  struct jpeg_decompress_struct srcinfo;
  struct jpeg_compress_struct dstinfo;
  struct jpeg_error_mgr jsrcerr, jdsterr;
  jvirt_barray_ptr * src_coef_arrays;
  jvirt_barray_ptr * dst_coef_arrays;
  FILE * input_file = NULL;
  FILE * output_file = NULL;
	
  /* -copy switch */
  JCOPY_OPTION copyoption	= JCOPYOPT_ALL;
	
  /* image transformation options */
  jpeg_transform_info transformoption;
  memset(&transformoption, 0, sizeof(jpeg_transform_info));
	
  boolean simple_progressive;
	
	// get a temporary filename
	char* tempfile = (char*) malloc(512);
	memset(tempfile, 0, 512);
	tmpnam(tempfile);
	
  try
  {
    /* Initialize the JPEG decompression object with default error handling. */
    srcinfo.err = jpeg_std_error(&jsrcerr);
    jsrcerr.error_exit = error_exit;
    jpeg_create_decompress(&srcinfo);
    /* Initialize the JPEG compression object with default error handling. */
    dstinfo.err = jpeg_std_error(&jdsterr);
    jdsterr.error_exit = error_exit;
    jpeg_create_compress(&dstinfo);
		
    /* Set up JPEG parameters. */
    simple_progressive = false;
    transformoption.transform = trans;
    transformoption.trim = false;
    transformoption.force_grayscale = false;
    dstinfo.err->trace_level = 0;
    jsrcerr.trace_level = jdsterr.trace_level;
    srcinfo.mem->max_memory_to_use = dstinfo.mem->max_memory_to_use;
		
    /* Open the input file. */
    if ((input_file = fopen(file, "rb")) == NULL) {
      return NULL;
		}
		
    /* Specify data source for decompression */
    jpeg_stdio_src(&srcinfo, input_file);
		
    /* Enable saving of extra markers that we want to copy */
    jcopy_markers_setup(&srcinfo, copyoption);
		
    /* Read file header */
    (void) jpeg_read_header(&srcinfo, TRUE);
		
    /* these are the size of the dct blocks */
    int dct_width = srcinfo.max_h_samp_factor * DCTSIZE;
    int dct_height = srcinfo.max_v_samp_factor * DCTSIZE;
		
    /* make sure image sizes are multiple of dct blocks size */
    if (srcinfo.image_width % dct_width != 0 || srcinfo.image_height % dct_height != 0)
    {
      jpeg_destroy_compress(&dstinfo);
      jpeg_destroy_decompress(&srcinfo);
      fclose(input_file);
      return NULL;
    }
		
    if ((output_file = fopen(tempfile, "wb")) == NULL)
    {
      jpeg_destroy_compress(&dstinfo);
      jpeg_destroy_decompress(&srcinfo);
      fclose(input_file);
      return NULL;
    }
		
    /* Any space needed by a transform option must be requested before
		 * jpeg_read_coefficients so that memory allocation will be done right.
		 */
    jtransform_request_workspace(&srcinfo, &transformoption);
		
    /* Read source file as DCT coefficients */
    src_coef_arrays = jpeg_read_coefficients(&srcinfo);
		
    /* Initialize destination compression parameters from source values */
    jpeg_copy_critical_parameters(&srcinfo, &dstinfo);
		
    /* Adjust destination parameters if required by transform options;
		 * also find out which set of coefficient arrays will hold the output.
		 */
    dst_coef_arrays = jtransform_adjust_parameters(&srcinfo, &dstinfo,
																									 src_coef_arrays,
																									 &transformoption);
		
    /* Specify data destination for compression */
    jpeg_stdio_dest(&dstinfo, output_file);
		
    /* Start compressor (note no image data is actually written here) */
    jpeg_write_coefficients(&dstinfo, dst_coef_arrays);
		
    /* Copy to the output file any extra markers that we want to preserve */
    jcopy_markers_execute(&srcinfo, &dstinfo, copyoption);
		
    /* Execute image transformation, if any */
    jtransform_execute_transformation(&srcinfo, &dstinfo,
																			src_coef_arrays,
																			&transformoption);
		
    /* Finish compression and release memory */
    jpeg_finish_compress(&dstinfo);
    jpeg_destroy_compress(&dstinfo);
    (void) jpeg_finish_decompress(&srcinfo);
    jpeg_destroy_decompress(&srcinfo);
		
    /* Close files, if we opened them */
    fclose(input_file);
    input_file = NULL;
    fclose(output_file);
    output_file = NULL;
		
    /* Done */
    return tempfile;
  }
  catch (...)
  {
    // close files
    if (input_file != NULL)
      fclose(input_file);
    if (output_file != NULL)
      fclose(output_file);
    remove(tempfile);
		
		// done
    return NULL;
  }
}

JXFORM_CODE exifOrientToJpegTransform(unsigned char orientation)
{
  switch (orientation)
  {
		case 2:
			return JXFORM_FLIP_H;
			
		case 3:
			return JXFORM_ROT_180;
			
		case 4:
			return JXFORM_FLIP_V;
			
		case 5:
			return JXFORM_TRANSPOSE;
			
		case 6:
			return JXFORM_ROT_90;
			
		case 7:
			return JXFORM_TRANSVERSE;
			
		case 8:
			return JXFORM_ROT_270;
			
		default:
			return JXFORM_NONE;
  }
}
