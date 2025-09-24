import hashlib
import connect_sql as cs
import datetime

class Register(object):
    # 회원가입 시 사용하는 유저의 정보
    def __init__(self, phone: str, password: str, nickname: str, gender: str, age: int, bio:str, profile_picture: str, timezone: str):
        self.__phone = phone
        self.__password = hashlib.sha256((password + phone).encode()).hexdigest()
        self.__nickname = nickname
        self.__gender = gender
        self.__age = age
        self.__bio = bio
        self.__profile_picture = profile_picture
        self.__timezone = timezone

        # 시작 금액은 0이므로 (가변가능)
        self.__hb_balance = 0

        # created_at은 어디를 기준으로 할 지 논의가 필요
        self.__created_at = datetime.datetime.now()

    def register_user(self):
        con = cs.connect_sql("", "", "", "")
        cur = con.cursor()

        try:
            # 만약 신규 가입이라면 INSERT를 진행하고,
            query = f"""INSERT INTO 
            User(phone, password_hash, nickname, gender, age, bio, 
            profile_picture, timezone, hb_balance, created_at) 
            VALUES({self.__phone}, {self.__password}, {self.__nickname}, {self.__gender},
            {self.__age}, {self.__bio}, {self.__profile_picture}, {self.__timezone}, {self.__hb_balance}, {self.__created_at})"""

        except:
            # uid를 기준으로 찾아서 수정, 재화/생성일은 수정할 필요가 없으므로 넣지 않음.
            temp = "유저 아이디"
            query = f"""UPDATE TableName SET
            phone = {self.__phone},
            password_hash = {self.__password}, 
            nickname = {self.__nickname},
            gender = {self.__gender},
            age = {self.__age}, 
            bio = {self.__bio}, 
            profile_picture = {self.__profile_picture}, 
            timezone = {self.__timezone}, 
            WHERE id = {temp}"""

        cur.execute(query)
        con.commit()
        con.close()
