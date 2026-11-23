using System;
using System.Collections.Generic;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("PrismaFrame")]
[assembly: AssemblyProduct("PrismaFrame")]
[assembly: AssemblyDescription("Otimizador de desempenho para jogos no Windows")]
[assembly: AssemblyVersion("1.2.0.0")]
[assembly: AssemblyFileVersion("1.2.0.0")]

namespace PrismaFrame
{
    public sealed class PrismaFrameRuntime
    {
        private static readonly HashSet<string> Files = new HashSet<string>(StringComparer.Ordinal)
        {
            "PrismaFrame.ps1", "PrismaFrame.xaml", "Tweaks.ps1", "Scanner.ps1", "Maintenance.ps1",
            "Tuning.ps1", "Recommendations.ps1", "WindowsTuning.ps1", "GameConfigTuning.ps1", "NvidiaTuning.ps1"
        };

        public string ExecutablePath
        {
            get { return typeof(PrismaFrameRuntime).Assembly.Location; }
        }

        public string ReadText(string name)
        {
            if (!Files.Contains(name))
                throw new ArgumentException("Recurso interno inválido.", "name");

            string resourceName = "PrismaFrame." + name;
            using (Stream source = typeof(PrismaFrameRuntime).Assembly.GetManifestResourceStream(resourceName))
            {
                if (source == null)
                    throw new InvalidOperationException("Recurso interno indisponível: " + name);

                using (var reader = new StreamReader(source, new UTF8Encoding(false, true), true))
                    return reader.ReadToEnd();
            }
        }
    }

    internal static class Program
    {
        private const string TestResultFile = "prismaframe-self-test.txt";
        private const string StartScript = @"
param($runtime, [bool]$openRecovery, [bool]$selfTest, [string]$captureDirectory)
$ErrorActionPreference = 'Stop'
$application = [scriptblock]::Create($runtime.ReadText('PrismaFrame.ps1'))
. $application -EmbeddedRuntime $runtime -OpenRecovery:$openRecovery -SelfTest:$selfTest -CaptureDirectory $captureDirectory
";

        [STAThread]
        private static int Main(string[] args)
        {
            string testDirectory = null;
            bool testing = args.Length > 0 && args[0] == "--self-test";
            try
            {
                bool openRecovery = args.Length == 1 && args[0] == "--recovery";
                if (testing)
                {
                    if (args.Length != 2 || String.IsNullOrWhiteSpace(args[1]))
                        return 2;

                    testDirectory = Path.GetFullPath(args[1]);
                    Directory.CreateDirectory(testDirectory);
                }
                else if (args.Length != 0 && !openRecovery)
                {
                    throw new ArgumentException("Abra o executável diretamente para iniciar o PrismaFrame.");
                }

                string report = RunWindow(new PrismaFrameRuntime(), openRecovery, testDirectory);
                if (testing)
                    File.WriteAllText(Path.Combine(testDirectory, TestResultFile), report, new UTF8Encoding(false));

                return 0;
            }
            catch (Exception error)
            {
                if (testing)
                {
                    if (testDirectory != null)
                    {
                        try { File.WriteAllText(Path.Combine(testDirectory, TestResultFile), error.ToString(), new UTF8Encoding(false)); }
                        catch (IOException) { return 1; }
                        catch (UnauthorizedAccessException) { return 1; }
                    }
                }
                else
                {
                    MessageBox.Show("O PrismaFrame não pôde ser aberto.\n\n" + error.GetBaseException().Message,
                        "PrismaFrame", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }

                return 1;
            }
        }

        private static string RunWindow(PrismaFrameRuntime runtime, bool openRecovery, string testDirectory)
        {
            // Use the Windows PowerShell module directory for both the UI and background runspaces.
            var modules = Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "Modules");
            if (!Directory.Exists(modules))
                throw new InvalidOperationException("O Windows PowerShell 5.1 não está disponível neste computador.");
            Environment.SetEnvironmentVariable("PSModulePath", modules, EnvironmentVariableTarget.Process);

            using (var runspace = RunspaceFactory.CreateRunspace())
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                runspace.Open();

                using (PowerShell shell = PowerShell.Create())
                {
                    shell.Runspace = runspace;
                    shell.AddScript(StartScript, false).AddArgument(runtime).AddArgument(openRecovery)
                        .AddArgument(testDirectory != null).AddArgument(testDirectory ?? String.Empty);
                    var output = shell.Invoke();
                    if (shell.HadErrors || shell.InvocationStateInfo.State != PSInvocationState.Completed)
                    {
                        string detail = shell.Streams.Error.Count > 0 ? shell.Streams.Error[0].ToString() : "A sessão não foi concluída.";
                        throw new InvalidOperationException(detail, shell.InvocationStateInfo.Reason);
                    }

                    var report = new StringBuilder();
                    foreach (PSObject line in output)
                        report.AppendLine(line.ToString());

                    return report.ToString();
                }
            }
        }
    }
}
