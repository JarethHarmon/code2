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
	
	public Node import;
	public ImageScanner iscan;
	public Database db_komi;
	
	public bool filter_by_default = true;
	public string thumbnail_path;
	public void SetThumbnailPath(string path) { thumbnail_path = path; }
	
	public override void _Ready() { 
		import = (Node) GetNode("/root/Import"); 
		iscan = (ImageScanner) GetNode("/root/ImageScanner");
		db_komi = (Database) GetNode("/root/Database");
	}
	
	public void ImportImages(string path, bool recursive) {
		iscan.ScanDirectories(@path, recursive);
		foreach (string image_path in iscan.GetImages()) ImportImage(image_path);
		iscan.Clear();
		db_komi.CheckpointKomi64();
	}
	
	public void CalcDifferenceHash(string path) {
		var stream = SixLabors.ImageSharp.Image.Load<SixLabors.ImageSharp.PixelFormats.Rgba32>(path);
		var algo = new DifferenceHash();
		ulong hash = algo.Hash(stream);
		GD.Print(hash);
	}
	
	static byte[] LoadFile(string path) { return (path.Length() < MAX_PATH_LENGTH) ? System.IO.File.ReadAllBytes(path) : Alphaleonis.Win32.Filesystem.File.ReadAllBytes(path); }
		
	/* uses ImageMagick so this method will be compatible with most formats I will likely create a less compatible 
	 * function for common image types that tries to be faster than ImageMagick */
	public void SaveThumbnail(string komi64) {
		string save_path = thumbnail_path + komi64 + ".jpg";
		string image_path = db_komi.GetKomiPathsFromDict(komi64)[0];
		SaveThumbnail(image_path, save_path);
	}
	static void SaveThumbnail(string image_path, string thumbnail_path) {
		try {
			var im = new MagickImage(image_path);
			im.Format = MagickFormat.Jpg;
			im.Quality = 50;
			im.Interlace = Interlace.Plane;
			//im.ColorSpace = ColorSpace.RGB; // not sure if needed
			im.Resize(256, 256);
			im.Strip();
			im.Write(thumbnail_path);
		} 
		catch (Exception ex) { GD.Print("ImageOp::SaveThumbnail() : ", ex); return; }
	}
	static bool IsImageCorrupt(string image_path) {
		try { var im = new MagickImage(image_path); }
		catch (MagickCorruptImageErrorException) { return true; }
		return false;
	}
	static string GetActualFormat(string image_path) {
		try { return new MagickImageInfo(image_path).Format.ToString().ToUpperInvariant().Replace("JPEG", "JPG"); }
		catch (MagickCorruptImageErrorException) { return ""; }
	}
	static Godot.Image LoadUnknownFormat(string image_path) {
		try {
			var im = new MagickImage(image_path);
			im.Format = MagickFormat.Jpg;
			im.Quality = 95;
			byte[] data = im.ToByteArray();
			var i = new Godot.Image();
			i.LoadJpgFromBuffer(data);
			return i;
		}
		catch (MagickCorruptImageErrorException) { return null; }
		catch (Exception) { return null; }
	}
	// two of my test images would not load as jpegs for some reason
	static Godot.Image LoadUnknownFormatAlt(string image_path) {
		try {
			var im = new MagickImage(image_path);
			im.Format = MagickFormat.Png;
			im.Quality = 95;
			byte[] data = im.ToByteArray();
			var i = new Godot.Image();
			i.LoadPngFromBuffer(data);
			return i;
		}
		catch (MagickCorruptImageErrorException) { return null; }
		catch (Exception) { return null; }
	}
	
	public void ImportImage(string image_path) {
		try {
			if (IsImageCorrupt(image_path)) return;
			string komihash = (string) import.Call("get_unsigned_komi_hash", image_path);
			string save_path = thumbnail_path + komihash + ".jpg"; 

			int err = db_komi.InsertKomi64Info(komihash, filter_by_default, new string[1]{image_path}, new string[0]);
			if (err != 0) return;
			SaveThumbnail(image_path, save_path);
		}
		catch (Exception ex) { GD.Print("ImageOp::ImportImage() : ", ex); return; }
	}
	
}
