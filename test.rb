io = IO.popen("lsof")
io.each do |line|
  if line.index("dumpscp")
    p line
    if line.split(" ").first == "scp"
      @uploading_file = line.split(" ").last
    end
  end
end

p @uploading_file
