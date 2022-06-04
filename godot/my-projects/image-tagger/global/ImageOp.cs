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
	public Node import;
	public ImageScanner iscan;
	
	public string thumbnail_path;
	public void SetThumbnailPath(string path) { thumbnail_path = path; }
	
	public override void _Ready() { 
		import = (Node) GetNode("/root/Import"); 
		iscan = (ImageScanner) GetNode("/root/ImageScanner");
	}
	
	public void ImportImages(string path) {
		iscan.ScanDirectories(@path);
		foreach (string image_path in iscan.GetImages()) ImportImage(image_path);
		iscan.Clear();
	}
	
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
			// temporary code to check if hashes collide too often; so far >4500 hashed with 0 collisions
			if (System.IO.File.Exists(thumbnail_path)) thumbnail_path += ".jpg";
			im.Write(thumbnail_path);
		} catch (Exception ex) { GD.Print("SaveThumbnail(): ", ex); return; }
	}
		
	public void ImportImage(string image_path) {
		try {
			string s_komihash = (string) import.Call("get_unsigned_komi_hash", image_path);
			string save_path = thumbnail_path + s_komihash + ".jpg"; 
			ulong komihash = ulong.Parse(s_komihash);
			SaveThumbnail(image_path, save_path);
			// add hash to database (also need to add metadata like file_size/extension/creation_time_utc/etc)
			// need to decide when/how this should interact with ImageScanner to be most efficient
		}
		catch (Exception ex) { GD.Print("ImportImage(): ", ex); return; }
	}
	
}
