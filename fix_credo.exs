defmodule FixCredo do
  def run do
    {json_str, 0} = System.cmd("mix", ["credo", "--strict", "--format", "json"])
    # Not using Jason, just a simple regex to find files with issues
    
    issues = parse_json(json_str)
    
    # Group issues by file
    files = Enum.group_by(issues, &(&1["filename"]))
    
    for {file, file_issues} <- files do
      content = File.read!(file)
      new_content = fix_file(content, file_issues)
      if new_content != content do
        File.write!(file, new_content)
        IO.puts("Fixed #{file}")
      end
    end
  end
  
  defp parse_json(str) do
    # Super hacky json parser since we don't know if Jason is available
    # Actually let's check if Jason is available
    if Code.ensure_loaded?(Jason) do
      Jason.decode!(str)["issues"]
    else
      IO.puts("Jason not loaded, can't parse JSON easily. Need to use a simpler method.")
      []
    end
  end

  defp fix_file(content, issues) do
    content
  end
end

if Code.ensure_loaded?(Jason) do
  FixCredo.run()
else
  # Mix config might have Jason
  Mix.install([:jason])
  FixCredo.run()
end
