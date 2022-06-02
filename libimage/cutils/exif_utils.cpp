
#include "cutils.h"
#include "exif_utils.h"

/* Read one byte, testing for EOF */
int read_1_byte (FILE *f)
{
  int c;
	
  c = getc(f);
  if (c == EOF)
    throw 1;
  return c;
}

/* Read 2 bytes, convert to unsigned int */
/* All 2-byte quantities in JPEG markers are MSB first */
unsigned int read_2_bytes (FILE *f)
{
  int c1, c2;
	
  c1 = getc(f);
  if (c1 == EOF)
    throw 1;
  c2 = getc(f);
  if (c2 == EOF)
    throw 1;
  return (((unsigned int) c1) << 8) + ((unsigned int) c2);
}

unsigned int getuvalue(unsigned char* buffer, unsigned int length, bool swap)
{
	int power16[4] = { 1, 256, 65536, 16777216 };
	unsigned int res = 0;
	for (unsigned int i=0; i<length; i++)
	{
		if (swap) res += buffer[i] * power16[i];
		else res += buffer[i] * power16[length-i-1];
	}
	return res;
}

int getsvalue(unsigned char* buffer, unsigned int length, bool swap)
{
	int power16[4] = { 1, 256, 65536, 16777216 };
	int res = 0;
	for (unsigned int i=0; i<length; i++)
	{
		if (swap) res += buffer[i] * power16[i];
		else res += buffer[i] * power16[length-i-1];
	}
	return res;
}

void writecharvalue(unsigned char *buffer, int length, bool swap, long data)
{
	unsigned long mask = 0xFF;
	mask <<= (length - 1)*8;
	
	int start = 0;
	int end   = length;
	int incr  = 1;
	
	if (swap)
	{
		start = length - 1;
		end   = -1;
		incr  = -1;
	}
	
	int nb = abs(end - start) - 1;
	for(int i = start;i != end; i += incr)
	{
		buffer[i] = (data & mask) >> (8 * nb--);
		mask >>= 8;
	}
}

int readint(FILE *file, int length, bool swap)
{
	unsigned char *buffer = new unsigned char[length];
	size_t read = fread(buffer, sizeof(unsigned char), length, file);
	if (read != length)
	{
		delete [] buffer;
		return -1;
	}
	int res = getuvalue(buffer, length, swap);
	delete [] buffer;
	return res;
}

bool writedata(FILE *file, int length, unsigned char *data)
{
	return (fwrite(data, sizeof(unsigned char), length, file) == length);
}

bool writenumdata(FILE *file, int length, bool swap, long data)
{
	unsigned char *buffer = new unsigned char[length * sizeof(unsigned char)];
	writecharvalue(buffer, length, swap, data);
	bool res = writedata(file, length, buffer);
	delete [] buffer;
	return res;
}

bool exif_orient(const char* file, unsigned char* orientation)
{
	if (orientation == NULL)
		return false;
	
	FILE * myfile;
	if (*orientation) {
		if ((myfile = fopen(file, "rb+")) == NULL) {
			//fprintf(stderr, "%s: can't open %s\n", progname, argv[i]);
			return false;
		}
	} else {
		if ((myfile = fopen(file, "rb")) == NULL) {
			//fprintf(stderr, "%s: can't open %s\n", progname, argv[i]);
			return false;
		}
	}
	
	int is_motorola; /* Flag for byte order */
	unsigned long exif_start, length, i;
	unsigned int offset, number_of_tags, tagnum;
	unsigned char* exif_data = new unsigned char[65536L];
	
	bool rc = true;
	try
	{
		exif_start = 0;
		
		/* Read File head, check for JPEG SOI + Exif APP1 */
		for (i = 0; i < 4; i++)
			exif_data[i] = (unsigned char) read_1_byte(myfile);
		
		// tiff file
		if (   (exif_data[0] == 0x49 && exif_data[1] == 0x49)
				|| (exif_data[0] == 0x4d && exif_data[1] == 0x4d))
		{
			// get length rewind it
			fseek(myfile, 0, SEEK_END);
			length = min(65536L, ftell(myfile));
			fseek(myfile, 0, SEEK_SET);
			if (fread(exif_data, sizeof(unsigned char), length, myfile) != length)
				throw 1;
		}
		else if (exif_data[0] != 0xFF ||
						 exif_data[1] != 0xD8/* ||
																	exif_data[2] != 0xFF ||
																	exif_data[3] != 0xE1*/)
		{
			throw 1;
		}
		else
		{
			/* Get the marker parameter length count */
			length = read_2_bytes(myfile);
			
			/* take jfif format into account */
			for (i = 0; i < 6; i++)
				exif_data[i] = (unsigned char) read_1_byte(myfile);
			if (   exif_data[0] == 0x4A
					&& exif_data[1] == 0x46
					&& exif_data[2] == 0x49
					&& exif_data[3] == 0x46
					&& exif_data[4] == 0x00)
			{
				// advance to start of exif data
				if (fseek(myfile, 22, SEEK_SET) != 0)
					return false;
				
				/* Get the marker parameter length count */
				length = read_2_bytes(myfile);
				
				// re-read header
				for (i = 0; i < 6; i++) {
					exif_data[i] = (unsigned char) read_1_byte(myfile);
				}
			}
			
			/* Check for "ICC_PROFILE" */
			if (memcmp(exif_data, "ICC_PROFILE", 6) == 0) {
				
				fseek(myfile, length-6, SEEK_CUR);
				i = ftell(myfile);
				
				// re-read length
				length = read_2_bytes(myfile);

				// re-read header
				for (i = 0; i < 6; i++) {
					exif_data[i] = (unsigned char) read_1_byte(myfile);
				}
			}
			
			
			/* Length includes itself, so must be at least 2 */
			/* Following Exif data length must be at least 6 */
			if (length < 8)
				throw 1;
			length -= 8;
			
			/* Length of an IFD entry */
			if (length < 12)
				throw 1;
			
			/* Check for "Exif" */
			if (exif_data[0] != 0x45 ||
					exif_data[1] != 0x78 ||
					exif_data[2] != 0x69 ||
					exif_data[3] != 0x66 ||
					exif_data[4] != 0 ||
					exif_data[5] != 0)
				throw 1;
			
			/* Read Exif body */
			exif_start = ftell(myfile);
			if (fread(exif_data, sizeof(unsigned char), length, myfile) != length)
				throw 1;
		}
		
		/* Discover byte order */
		if (exif_data[0] == 0x49 && exif_data[1] == 0x49)
			is_motorola = 0;
		else if (exif_data[0] == 0x4D && exif_data[1] == 0x4D)
			is_motorola = 1;
		else
			throw 1;
		
		/* Check Tag Mark */
		if (is_motorola) {
			if (exif_data[2] != 0) throw 1;
			if (exif_data[3] != 0x2A) throw 1;
		} else {
			if (exif_data[3] != 0) throw 1;
			if (exif_data[2] != 0x2A) throw 1;
		}
		
		/* Get first IFD offset (offset to IFD0) */
		if (is_motorola) {
			if (exif_data[4] != 0) throw 1;
			if (exif_data[5] != 0) throw 1;
			offset = exif_data[6];
			offset <<= 8;
			offset += exif_data[7];
		} else {
			if (exif_data[7] != 0) throw 1;
			if (exif_data[6] != 0) throw 1;
			offset = exif_data[5];
			offset <<= 8;
			offset += exif_data[4];
		}
		if (offset > length - 2) throw 1; /* check end of data segment */
		
		/* Get the number of directory entries contained in this IFD */
		if (is_motorola) {
			number_of_tags = exif_data[offset];
			number_of_tags <<= 8;
			number_of_tags += exif_data[offset+1];
		} else {
			number_of_tags = exif_data[offset+1];
			number_of_tags <<= 8;
			number_of_tags += exif_data[offset];
		}
		if (number_of_tags == 0) throw 1;
		offset += 2;
		
		// record this
		unsigned int directory_start = offset;
		unsigned int directory_tags = number_of_tags;
		
		/* Search for Orientation Tag in IFD0 */
		for (;;) {
			if (offset > length - 12) throw 1; /* check end of data segment */
			/* Get Tag number */
			if (is_motorola) {
				tagnum = exif_data[offset];
				tagnum <<= 8;
				tagnum += exif_data[offset+1];
			} else {
				tagnum = exif_data[offset+1];
				tagnum <<= 8;
				tagnum += exif_data[offset];
			}
			if (tagnum == 0x0112) break; /* found Orientation Tag */
			if (--number_of_tags == 0) throw 1;
			offset += 12;
		}
		
		if (*orientation) {
			/* Set the Orientation value */
			if (is_motorola) {
				exif_data[offset+2] = 0; /* Format = unsigned short (2 octets) */
				exif_data[offset+3] = 3;
				exif_data[offset+4] = 0; /* Number Of Components = 1 */
				exif_data[offset+5] = 0;
				exif_data[offset+6] = 0;
				exif_data[offset+7] = 1;
				exif_data[offset+8] = 0;
				exif_data[offset+9] = (unsigned char) *orientation;
				exif_data[offset+10] = 0;
				exif_data[offset+11] = 0;
			} else {
				exif_data[offset+2] = 3; /* Format = unsigned short (2 octets) */
				exif_data[offset+3] = 0;
				exif_data[offset+4] = 1; /* Number Of Components = 1 */
				exif_data[offset+5] = 0;
				exif_data[offset+6] = 0;
				exif_data[offset+7] = 0;
				exif_data[offset+8] = (unsigned char) *orientation;
				exif_data[offset+9] = 0;
				exif_data[offset+10] = 0;
				exif_data[offset+11] = 0;
			}
			//fseek(myfile, (4 + 2 + 6 + 2) + offset, SEEK_SET);
			fseek(myfile, -length + offset + 2, SEEK_CUR);
			fwrite(exif_data + 2 + offset, 1, 12, myfile);
			
			// now get IFD1 offset
			offset = directory_start + directory_tags * 12;
			unsigned int ifd1_offset = getuvalue(exif_data+offset, 4, !is_motorola);
			if (ifd1_offset != 0) {
				
				// now go to it
				fseek(myfile, exif_start + ifd1_offset, SEEK_SET);
				number_of_tags = readint(myfile, 2, !is_motorola);
				length = number_of_tags * 12;
				if (fread(exif_data, sizeof(unsigned char), length, myfile) != length)
					throw 1;
				
				/* Search for Orientation Tag in IFD1 */
				offset = 0;
				for (;;) {
					if (offset > length - 12) throw 1; /* check end of data segment */
					/* Get Tag number */
					if (is_motorola) {
						tagnum = exif_data[offset];
						tagnum <<= 8;
						tagnum += exif_data[offset+1];
					} else {
						tagnum = exif_data[offset+1];
						tagnum <<= 8;
						tagnum += exif_data[offset];
					}
					if (tagnum == 0x0112) break; /* found Orientation Tag */
					if (--number_of_tags == 0) throw 1;
					offset += 12;
				}
				
				if (is_motorola) {
					exif_data[offset+2] = 0; /* Format = unsigned short (2 octets) */
					exif_data[offset+3] = 3;
					exif_data[offset+4] = 0; /* Number Of Components = 1 */
					exif_data[offset+5] = 0;
					exif_data[offset+6] = 0;
					exif_data[offset+7] = 1;
					exif_data[offset+8] = 0;
					exif_data[offset+9] = (unsigned char) *orientation;
					exif_data[offset+10] = 0;
					exif_data[offset+11] = 0;
				} else {
					exif_data[offset+2] = 3; /* Format = unsigned short (2 octets) */
					exif_data[offset+3] = 0;
					exif_data[offset+4] = 1; /* Number Of Components = 1 */
					exif_data[offset+5] = 0;
					exif_data[offset+6] = 0;
					exif_data[offset+7] = 0;
					exif_data[offset+8] = (unsigned char) *orientation;
					exif_data[offset+9] = 0;
					exif_data[offset+10] = 0;
					exif_data[offset+11] = 0;
				}
				//fseek(myfile, (4 + 2 + 6 + 2) + offset, SEEK_SET);
				fseek(myfile, -length + offset + 2, SEEK_CUR);
				fwrite(exif_data + 2 + offset, 1, 12, myfile);
			}
			
		} else {
			/* Get the Orientation value */
			if (is_motorola) {
				if (exif_data[offset+8] != 0) throw 1;
				*orientation = exif_data[offset+9];
			} else {
				if (exif_data[offset+9] != 0) throw 1;
				*orientation = exif_data[offset+8];
			}
			if (*orientation > 8) throw 1;
		}
	}
	catch (...)
	{
		rc = false;
	}
	
	/* All done. */
	delete [] exif_data;
	fclose(myfile);
	return rc;
}
