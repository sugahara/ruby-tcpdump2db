# -*- coding: utf-8 -*-
#require 'pcap'
require 'mysql'
require 'fileutils'

def get_header(line)
  line = line.chomp
  frame_prop = line.split(";")
  month = frame_prop[0].split(",")[0].split(" ")[0]
  day = frame_prop[0].split(",")[0].split(" ")[1]
  year = frame_prop[0].split(",")[1].split(" ")[0]
  hour = frame_prop[0].split(",")[1].split(" ")[1].split(":")[0]
  minute = frame_prop[0].split(",")[1].split(" ")[1].split(":")[1]
  second =  frame_prop[0].split(",")[1].split(" ")[1].split(":")[2].split(".")[0]
  micro_second = frame_prop[0].split(",")[1].split(" ")[1].split(":")[2].split(".")[1][0..5]
  frame_time = Time.local(year, month, day, hour, minute, second)
  frame_protocols = frame_prop[1].split(":")
  eth_src = frame_prop[2]
  eth_dst = frame_prop[3]
  ip_src = frame_prop[4]
  ip_dst = frame_prop[5]
  tcp_srcport = frame_prop[6]
  tcp_dstport = frame_prop[7]
  udp_srcport = frame_prop[8]
  udp_dstport = frame_prop[9]
  length = frame_prop[10]
  # ICMPパケットを分析した際の対策
  if ip_src.include?(",") || ip_dst.include?(",")
    ip_src = ip_src.split(",")[0]
    ip_dst = ip_dst.split(",")[0]
  end

  #ヘッダの順番はテーブルのフィールドの順で
  header = {
    "time" => frame_time.strftime("%Y-%m-%d %H:%M:%S"),
    "micro_second" => micro_second,
    "protocol_1" => frame_protocols[0],
    "protocol_2" => frame_protocols[1],
    "protocol_3" => frame_protocols[2],
    "protocol_4" => frame_protocols[3],
    "protocol_5" => frame_protocols[4],
    "eth_src" => eth_src,
    "eth_dst" => eth_dst,
    "ip_src" => ip_src,
    "ip_dst" => ip_dst
    #"tcp_srcport" => frame_prop[6],
    #"tcp_dstport" => frame_prop[7],
    #"udp_srcport" => frame_prop[8],
    #"udp_dstport" => frame_prop[9],
  }
  if header["protocol_3"] == "tcp"
    header["port_src"] = frame_prop[6]
    header["port_dst"] = frame_prop[7]
  elsif header["protocol_3"] == "udp"
    header["port_src"] = frame_prop[8]
    header["port_dst"] = frame_prop[9]
  else
    header["port_src"] = nil
    header["port_dst"] = nil
  end
  header["length"] = length

  header
end


db_host = ARGV[0]
db_user_name = ARGV[1]
db_pass = ARGV[2]
db_name = ARGV[3]

@db = Mysql::init()
@db.options(Mysql::OPT_LOCAL_INFILE)
@db.real_connect(db_host, db_user_name, db_pass, db_name)

puts "Database server connected."

io = IO.popen("lsof")
io.each do |line|
  if line.index("dumpscp") && line.split(" ").first == "scp"
    @uploading_file = line.split(" ").last
  end
end

puts "Opening file check is completed."

@filename = ARGV[4...ARGV.size]
@filename.delete(@uploading_file)
puts "Uploading file is #{@uploading_file}"
p @filename
@filename.each do |fn|
  puts "Inserting #{fn}"
  @table_name = File::basename(fn, ".pcap")
  @dirname = File.dirname(fn)

  total_start = Time.new
  # create table
  sql = "show tables from `#{db_name}` like '#{@table_name}'"
  #not exist same named table
  if @db.query(sql).num_rows() < 1
    
    #sql = "CREATE TABLE `#{db_name}`.`#{@table_name}` (`number` INT NOT NULL DEFAULT NULL AUTO_INCREMENT PRIMARY KEY ,`time` DATETIME NOT NULL ,`micro_second` INT NOT NULL,`protocol_1` TEXT DEFAULT NULL ,`protocol_2` TEXT DEFAULT NULL ,`protocol_3` TEXT DEFAULT NULL ,`protocol_4` TEXT DEFAULT NULL ,`eth_src` TEXT DEFAULT NULL ,`eth_dst` TEXT DEFAULT NULL , `ip_src` TEXT DEFAULT NULL ,`ip_dst` TEXT DEFAULT NULL ,`tcp_srcport` INT DEFAULT NULL ,`tcp_dstport` INT DEFAULT NULL ,`udp_srcport` INT DEFAULT NULL,`udp_dstport` INT DEFAULT NULL, `length` INT DEFAULT NULL) ENGINE = MYISAM"
    sql = "CREATE TABLE `#{db_name}`.`#{@table_name}` (`number` INT NOT NULL DEFAULT NULL AUTO_INCREMENT PRIMARY KEY ,`time` DATETIME NOT NULL ,`micro_second` INT NOT NULL,`protocol_1` TEXT DEFAULT NULL ,`protocol_2` TEXT DEFAULT NULL ,`protocol_3` TEXT DEFAULT NULL ,`protocol_4` TEXT DEFAULT NULL ,`protocol_5` TEXT DEFAULT NULL ,`eth_src` TEXT DEFAULT NULL ,`eth_dst` TEXT DEFAULT NULL , `ip_src` TEXT DEFAULT NULL ,`ip_dst` TEXT DEFAULT NULL ,`port_src` INT DEFAULT NULL ,`port_dst` INT DEFAULT NULL, `length` INT DEFAULT NULL) ENGINE = MYISAM"
    @db.query(sql)
    
    puts "tshark_start"
    
    `tshark -r #{fn} -T fields -e frame.time -e frame.protocols -e eth.src -e eth.dst -e ip.src -e ip.dst -e tcp.srcport -e tcp.dstport -e udp.srcport -e udp.dstport -e frame.len -E separator=\\; > #{@dirname}/temp.txt;`
    
    puts "tshark finished"
    puts "getting header"
    header_start = Time.new
    #lines = result.rstrip.split(/\r?\n/).map {|line| line.chomp }
    file_temp = File.open("#{@dirname}/temp.txt",'r')
    # get header info from lines
    file_csv = File.open("#{@dirname}/data.csv",'w')
    file_temp.each do |line|
      header = get_header(line)
      csv_line = 'NULL,'
      header.each do |key,value|
        if value != "" && value != nil
          csv_line+="\"#{value}\","
        else
          csv_line+='NULL,'
        end
      end
      csv_line = csv_line.chop
      file_csv.puts csv_line
    end
    
    file_csv.close
    file_temp.close
    puts "header output finished"
    header_end = Time.new
    p header_end - header_start
    sql = "LOAD DATA LOCAL INFILE '#{@dirname}/data.csv' INTO TABLE `#{@table_name}` FIELDS TERMINATED BY ',' ENCLOSED BY '\"' LINES TERMINATED BY '\\n'"
    @db.query(sql)
    end_time = Time.new
    
    puts "LOAD DATA TIME: #{end_time - header_end}"
    
    puts "TOTALEND: #{end_time - total_start}"
  end
end
FileUtils.rm("#{@dirname}/data.csv")
FileUtils.rm("#{@dirname}/temp.txt")
