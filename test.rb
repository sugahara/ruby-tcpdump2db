require 'mysql'
@db = Mysql::init()
@db.options(Mysql::OPT_LOCAL_INFILE)
@db.real_connect("133.101.57.201","ruby","suga0329","tcpdump")

sql = "show tables from tcpdump like `test`"

@db.query(sql)
