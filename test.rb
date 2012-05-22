io = IO.popen("lsof")
io.each do |line|
  if line.index("dumpscp") && line.split(" ").first == "scp"
    @uploading_file = line.split(" ").last
  end
end

p @uploading_file
