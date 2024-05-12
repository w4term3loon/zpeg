The JPEG File Interchange Format (JFIF) is an image file format standard published as ITU-T
Recommendation T. 871 and ISO/IEC 10918-5. It defines supplementary specifications for the
container format that contains the image data encoded with the JPEG algorithm.
Source: https://en.wikipedia.org/wiki/JPEG_File_Interchange_Format

A JFIF file consists of a sequence of markers or marker segments (for details refer to JPEG, Syntax and structure).
Each marker consists of two bytes: an 0xFF byte followed by a byte which is not equal to 0x00 or 0xFF and specifies
the type of the marker. Some markers stand alone, but most indicate the start of a marker segment that contains
data bytes according to the following pattern:


