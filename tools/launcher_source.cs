using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

public class Launcher
{
    [STAThread]
    public static void Main()
    {
        string dir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
        string exe = Path.Combine(dir, "batomon_showdown.exe");

        if (!File.Exists(exe))
        {
            MessageBox.Show("Could not find batomon_showdown.exe", "Batomon Showdown",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
            return;
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = exe,
                Arguments = "--rendering-driver opengl3",
                UseShellExecute = true
            });
        }
        catch (Exception ex)
        {
            MessageBox.Show("Failed to launch: " + ex.Message, "Error",
                MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
