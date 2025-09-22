import pymysql
import hashlib

_salt: str = "saltpepper"

# sql 연결
def _connect_sql():
    connect = pymysql.connect(
        host="localhost", # DB 구성 후 변경
        user="", # DB 구성 후 변경
        passwd="", # DB 구성 후 변경
        db="", # DB 구성 후 변경
        charset="utf8"
    )

    return connect

class Register(object):
    # 회원가입 시 사용하는 유저의 정보
    def __init__(self, username: str, phone_number: str, password: str):
        self.__username = username
        self.__phone_number = phone_number
        # 비밀번호는 암호화해서 가지고 있기 (넘겨 받기 전에 암호화를 하고 넘긴다면 코드가 바뀔수도 있음)
        self.__password = hashlib.sha256((password + _salt).encode()).hexdigest()

    def register_user(self):
        con = _connect_sql()
        cur = con.cursor()

        try:
            # 만약 신규 가입이라면 INSERT를 진행하고,
            query = f"""INSERT INTO TableName(phone_number, username, password) 
            VALUES({self.__username}, {self.__password}, {self.__phone_number})"""

        except:
            # 만약 수정이 필요한 경우 전화번호가 PK이므로 PK를 기준으로 찾는다.
            query = f"UPDATE TableName SET username = {self.__username}, password = {self.__password} WHERE phone_number = {self.__phone_number}"

        cur.execute(query)
        con.commit()
        con.close()

    '''
    이하는 프로필 설정 기능이 될거같습니다
    def create_profile(self):
        con = _connect_sql()
        cur = con.cursor()
        
        # UID = Auto Increasement 기준으로 작성
        try:
            query = f"""INSERT INTO TableName(gender, age, bio, coin, profile_picture, level, today_count) 
            VALUES({self.__gender}, {self.__gender}, {self.__age}, {self.__bio}, {self.__coin}, {self.__profile_picture}, {self.__level}, {self.__today_count})"""

        except:
            query = f"""UPDATE TableName 
            SET gender = {self.__gender}, 
            age = {self.__age}, 
            bio = {self.__bio}, 
            coin = {self.__coin}, 
            profile_picture = {self.__profile_picture}, 
            level = {self.__level}, 
            today_count = {self.__today_count} 
            WHERE phone_number = {self.__phone_number}"""

        cur.execute(query, (self.__username, self.__password, self.__phone_number))
        
        con.commit()
        con.close()
    '''
