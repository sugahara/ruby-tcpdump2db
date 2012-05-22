io = IO.popen("lsof")
io.each do |line|
  p line
  if line.index("scpdump")
    if line.split(" ").first == "scp"
      @uploading_file = line.split(" ").last
    end
  end
end

p @uploading_file
