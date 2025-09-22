import pymysql

# sql 연결
def connect_sql(host, user, password, database):
    connect = pymysql.connect(
        host=host, # DB 구성 후 변경
        user=user, # DB 구성 후 변경
        password=password, # DB 구성 후 변경
        db=database, # DB 구성 후 변경
        charset="utf8"
    )

    return connect