using Godot;
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Security.Cryptography;
using Alphaleonis.Win32.Filesystem;
using ImageMagick;
using CoenM.ImageHash;
using CoenM.ImageHash.HashAlgorithms;

public class ImageOp : Node
{
	public const int MAX_PATH_LENGTH = 256;
	public Label label;
	
	public void CalcDifferenceHash(string path) {
		var stream = SixLabors.ImageSharp.Image.Load<SixLabors.ImageSharp.PixelFormats.Rgba32>(path);
		var algo = new DifferenceHash();
		ulong hash = algo.Hash(stream);
		GD.Print(hash);
	}
	static byte[] LoadFile(string path) { return (path.Length() < MAX_PATH_LENGTH) ? System.IO.File.ReadAllBytes(path) : Alphaleonis.Win32.Filesystem.File.ReadAllBytes(path); }
	
	static string CalcSHA256Hash(string path) {
		try {
			var sha256 = SHA256.Create();
			//byte[] hash = sha256.ComputeHash(Encoding.UTF8.GetBytes(LoadFile(path)));
			byte[] hash = sha256.ComputeHash(LoadFile(path));
			StringBuilder build = new StringBuilder();
			for (int i = 0; i < hash.Length; i++) build.Append(hash[i].ToString("x2"));
			sha256.Dispose();
			return build.ToString();
		}
		catch (Exception ex) { GD.Print("CalcSHA256(): ", ex); return ""; }
	}
	
	static string CalcSHA256Checksum(string path) {
		try {
			var sha = SHA256.Create();
			var fs = System.IO.File.OpenRead(path); // add support for long filepaths
			string sha256 = BitConverter.ToString(sha.ComputeHash(fs)).Replace("-", "").ToLowerInvariant();
			fs.Dispose();
			sha.Dispose();
			return sha256;
		}
		catch (Exception ex) { GD.Print("CalcSHA256(): ", ex); return ""; }
	}
	
	/* uses ImageMagick so this method will be compatible with most formats I will likely create a less compatible 
	 * function for common image types that tries to be faster than ImageMagick */
	static void SaveThumbnail(string image_path, string thumbnail_path) {
		try {
			var im = new MagickImage(image_path);
			im.Format = MagickFormat.Jpg;
			im.Quality = 50;
			im.Interlace = Interlace.Plane;
			im.Resize(256, 256);
			im.Strip();
			im.Write(thumbnail_path);
		} catch (Exception ex) { GD.Print("SaveThumbnail(): ", ex); return; }
	}
	
	public void ImportImage(string image_path) {
		
	}
	
}
