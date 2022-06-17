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
	public const long KB = 1024;
	public const long MB = 1048576;
	public const long AVG_THUMBNAIL_SIZE = 7424; // 7.25KB
	
	public Node import;
	public Node signals;
	public ImageScanner iscan;
	public Database db;
	
	public bool filter_by_default = true;
	public string thumbnail_path;
	public void SetThumbnailPath(string path) { thumbnail_path = path; }
	
	public override void _Ready() { 
		import = (Node) GetNode("/root/Import"); 
		signals = (Node) GetNode("/root/Signals");
		iscan = (ImageScanner) GetNode("/root/ImageScanner");
		db = (Database) GetNode("/root/Database");
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
		string image_path = db.GetKomiPathsFromDict(komi64)[0];
		SaveThumbnail(image_path, save_path);
	}
	static void SaveThumbnail(string image_path, string thumbnail_path) {
		try {
			var im = new MagickImage(image_path);
			im.Format = MagickFormat.Jpg;
			im.Quality = 50;
			//im.Interlace = Interlace.Plane; // small sample test was larger
			im.Resize(256, 256);
			im.Strip();
			im.Write(thumbnail_path);
			new ImageOptimizer().Compress(thumbnail_path);
		} 
		catch (Exception ex) { GD.Print("ImageOp::SaveThumbnail() : ", ex); return; }
	}
	static void SaveMinimalThumbnail(string image_path, string thumbnail_path) {
		try {
			var im = new MagickImage(image_path);
			im.Format = MagickFormat.Png;
			im.Strip();
			im.Write(thumbnail_path);
			new ImageOptimizer().LosslessCompress(thumbnail_path);
		}
		catch (Exception ex) { GD.Print("ImageOp::SaveMinimalThumbnail() : ", ex); return; }
	}
	static bool IsImageCorrupt(string image_path) {
		try { var im = new MagickImage(image_path); return false; }
		catch (MagickCorruptImageErrorException) { GD.Print("err (corrupt) ::: ", image_path); return true; }
		catch (MagickBlobErrorException) { GD.Print("err (blob) ::: ", image_path); return true; }
		catch (Exception) { return true; }
	}
	static string GetActualFormat(string image_path) {
		try { return new MagickImageInfo(image_path).Format.ToString().ToUpperInvariant().Replace("JPEG", "JPG"); }
		catch (MagickCorruptImageErrorException) { return ""; }
		catch (Exception ex) { return ""; }
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
	
	public void ImportImages(string path, bool recursive) {
		int image_count = iscan.ScanDirectories(@path, recursive);
		if (image_count <= 0) return; 								// no images to import
		int success_count = 0;
		
		string iid = db.GetRandomID(4); 							// gets a random 32 bit ID	
		iid = "C" + iid;											// collection names cannot start with a number
		db.AddImportInfoToDatabase(iid, "", path);					// 				
		signals.Call("create_import_button", iid);					//
		
		// change ImportImage to return an int and count the number of corrupt and duplicate images
		//foreach (string image_path in iscan.GetImages()) ImportImage(image_path, iid);
		foreach ((string, long, long) tuple in iscan.GetImages()) {
			int err = ImportImage(tuple, iid);
			if (err == 0) {
				success_count++;
				db.IncrementImportSuccessCount(iid);
				signals.EmitSignal("update_button", success_count, iid);
			}
			else if (err == 1) db.IncrementImportDuplicateCount(iid);
			else if (err < 0) db.IncrementImportFailCount(iid);
		}
	
		db.CheckpointImport();
		db.CheckpointKomi64();
	}
	
	//public void ImportImage(string image_path, string import_id) {
	public int ImportImage((string, long, long) tuple, string import_id) {
		try {
			(string image_path, long image_creation_utc, long image_size) = tuple;
			if (IsImageCorrupt(image_path)) return -1;
			
			string komihash = (string) import.Call("get_komi_hash", image_path);
			string save_path = thumbnail_path + komihash;
			
			if (db.ImportGroupHasKomi(import_id, komihash)) return 1;
			
			db.InsertImportGroup(import_id, komihash, image_path, image_size, image_creation_utc);
			int err = db.InsertKomi64Info(komihash, filter_by_default, new string[1]{image_path}, new string[0], image_size, image_creation_utc);
			if (err < 0) return err;
			
			if (image_size < AVG_THUMBNAIL_SIZE) SaveMinimalThumbnail(image_path, save_path + ".png");
			else SaveThumbnail(image_path, save_path + ".jpg");
			
			return 0;
		}
		catch (Exception ex) { GD.Print("ImageOp::ImportImage() : ", ex); return -1; }
	}
	
}
