from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
import json
import zipfile

ROOT = Path(__file__).parent
OUT = ROOT / 'output/2026-09-09/article-01-carousel'
OUT.mkdir(parents=True, exist_ok=True)
BG = ROOT / 'assets/article-backgrounds/2026-09-09/article-01-sh-building.jpg'

NAVY = '#0D1B3E'
PANEL = '#18325A'
BLUE = '#1F5ADB'
ORANGE = '#F5A623'
COOL_GRAY = '#D9E2EC'
MUTED = '#AEBCCF'
WHITE = '#FFFFFF'


def font(size, bold=False):
    f = ImageFont.truetype('C:/Windows/Fonts/NotoSansKR-VF.ttf', size)
    f.set_variation_by_axes([700 if bold else 400])
    return f


def write(x, y, value, size=30, color=COOL_GRAY, bold=False, width=780, line_height=1.42):
    for line in value.split('\n'):
        assert d.textlength(line, font=font(size, bold)) <= width, (line, size)
        d.text((x, y), line, font=font(size, bold), fill=color)
        y += round(size * line_height)
    return y


def start(number, label, title, photo=False):
    global im, d
    im = Image.new('RGB', (1080, 1350), NAVY)
    if photo:
        im = ImageOps.fit(Image.open(BG).convert('RGB'), (1080, 1350), centering=(0.5, 0.46))
        # 기존 카드보다 기사 사진이 잘 보이도록 다크 오버레이를 44%로 조정한다.
        im = Image.blend(im, Image.new('RGB', im.size, NAVY), 0.44)
    d = ImageDraw.Draw(im)
    if not photo:
        d.ellipse((-180, -180, 430, 430), fill='#102C56')
        d.ellipse((770, 930, 1280, 1440), fill='#132948')
    write(150, 68, f'LAND BRIEF / {number:02d}—07', 22, MUTED, True)
    d.rounded_rectangle((150, 175, 930, 255), radius=18, fill=ORANGE)
    write(180, 187, label, 36, NAVY, True, 720)
    write(150, 320, title, 70 if number == 1 else 54, WHITE, True, 780, 1.30)
    d.line((150, 1230, 930, 1230), fill='#708199', width=1)
    write(150, 1250, '출처: 한국건설신문 (2026.09.09)', 20, MUTED, False, 520)
    write(713, 1284, '@landbrief.daily', 22, ORANGE, True, 217)
    if photo:
        write(150, 1187, '기사 내 자료 · 한국건설신문 / SH 제공', 20, COOL_GRAY, False, 500)


def box(y, label, body, height=176, accent=ORANGE):
    d.rounded_rectangle((150, y, 930, y + height), radius=22, fill=PANEL)
    d.rectangle((150, y + 22, 158, y + height - 22), fill=accent)
    write(184, y + 20, label, 33, accent, True, 700)
    write(184, y + 78, body, 29, COOL_GRAY, False, 700, 1.40)


def save(number):
    im.save(OUT / f'{number:02d}.png')


start(1, 'SH 재개발임대 · 재공고', '3,821세대\n9월 29일 접수', True)
write(150, 615, '연기됐던 모집이 가점 기준을 조정해 다시 나왔습니다', 31, COOL_GRAY, False)
box(810, '가장 먼저 볼 변화', '사회취약계층 가점은 되살리고\n연령 가점은 삭제', 205)
save(1)

start(2, '왜 중요한가', '7월 공고 연기 뒤\n기준을 다시 손봤습니다')
box(515, '7월 30일 · 최초 공고', '가점 기준을 변경해 모집 공고', 170)
box(710, '8월 10일 · 연기 결정', '사회적 배려 요소를 다시 검토', 170, BLUE)
box(905, '9월 9일 · 재공고', '취약계층 가점 복원 · 연령 가점 삭제', 190)
save(2)

start(3, '공급 규모', '공가와 예비입주자\n모집을 구분하세요')
box(525, '잔여 공가', '1,675세대\n퇴거·계약 취소 등으로 발생', 210)
box(760, '예비입주자', '2,146세대\n향후 공가 발생에 대비한 모집', 210, BLUE)
write(150, 1035, '합계 모집 규모 3,821세대', 36, ORANGE, True)
write(150, 1095, '재개발 철거 세입자 우선공급 후 남은 소형 주택', 27, COOL_GRAY)
save(3)

start(4, '신청 대상', '자격 기준일은\n9월 9일입니다')
box(500, '거주·주택 요건', '서울시 거주 · 무주택 세대구성원', 165)
box(690, '소득 기준', '도시근로자 월평균 소득\n1순위 50% 이하 · 2순위 70% 이하', 205, BLUE)
box(920, '자산 기준', '총자산 3억4,500만원 이하\n자동차 4,542만원 이하', 205)
save(4)

start(5, '주택 유형', '전용 39㎡ 이하\n재개발임대주택')
box(535, '공급 성격', '재개발 철거 세입자에게 먼저 공급한 뒤\n남은 공가를 일반 공급', 205)
box(765, '신청 전 확인', '단지별 위치·면적·임대조건은\nSH 모집공고에서 개별 확인', 205, BLUE)
write(150, 1040, '3,821세대가 모두 즉시 입주 가능한 공가는 아닙니다.', 28, COOL_GRAY)
save(5)

start(6, '접수 일정', '선순위와 후순위\n접수일이 다릅니다')
box(500, '9.29 ~ 10.2 · 선순위', '인터넷·모바일 청약 접수', 165)
box(690, '9.30 ~ 10.2 · 방문', '고령자·장애인 등 인터넷 사용이 어려운 신청자\nSH 본사 2층 대강당', 205, BLUE)
box(920, '10.8 · 후순위', '선순위 신청이 공급 세대의 200%를\n초과하면 후순위는 접수하지 않음', 205)
save(6)

start(7, '다음 확인', '발표와 입주까지\n이 일정을 확인하세요')
box(500, '10월 23일', '서류 심사 대상자 발표', 155)
box(680, '2027년 3월 30일', '최종 당첨자 발표', 155, BLUE)
box(860, '2027년 4월경', '입주 가능 예정', 155)
write(150, 1060, '후순위 접수 여부와 단지별 임대조건은\nSH 인터넷청약시스템 공고에서 다시 확인', 29, COOL_GRAY)
save(7)

caption = '''🏠 서울 재개발임대주택 3,821세대가 재공고됐습니다.
선순위 접수는 9월 29일부터 10월 2일까지이며, 연기 전 공고와 달라진 가점 기준도 확인해야 합니다.

📌 모집 규모
잔여 공가 1,675세대와 예비입주자 2,146세대를 모집합니다. 공급 주택은 재개발 철거 세입자 우선공급 후 남은 전용 39㎡ 이하 재개발임대주택입니다.

👥 일반공급 자격
9월 9일 기준 서울시 거주 무주택 세대구성원으로, 소득은 도시근로자 월평균 소득 70% 이하입니다. 1순위는 50% 이하, 2순위는 70% 이하이며 총자산 3억4,500만원·자동차 4,542만원 이하 기준도 적용됩니다.

🗓️ 접수 일정
선순위 9월 29일~10월 2일 / 방문 접수 9월 30일~10월 2일 / 후순위 10월 8일입니다. 선순위 신청자가 공급 세대의 200%를 초과하면 후순위 접수는 진행하지 않습니다.

🔎 다음 확인
서류 심사 대상자는 10월 23일, 최종 당첨자는 2027년 3월 30일 발표 예정입니다. 단지별 위치·면적·임대조건은 SH 모집공고에서 확인해야 합니다.

신청 전 가장 먼저 확인할 조건은 소득 기준과 선순위 여부 중 어느 쪽인가요?

출처: 한국건설신문

#SH재개발임대 #서울임대주택 #재개발임대주택 #SH청약 #입주자모집
'''
(OUT / 'caption.txt').write_text(caption, encoding='utf-8-sig')

candidates = json.loads((ROOT / 'output/2026-09-09/candidates.json').read_text(encoding='utf-8-sig'))
article = candidates[0]
detail = {
    'number': 1,
    'title': article['title'],
    'source': article['source'],
    'displaySource': '한국건설신문',
    'sourceUrl': 'http://www.conslove.co.kr/news/articleView.html?idxno=89545',
    'published': '2026-09-09 16:56',
    'fetchStatus': 'verified',
    'imageUsed': str(BG),
    'imageAttribution': 'SH 본사 사옥 전경. 사진=SH / 기사 내 자료',
    'imagePolicy': '인물 없는 건물 전경 사진을 표지에만 사용',
    'verification': '기사 원문 전체 확인. 공가 1,675세대와 예비입주자 2,146세대를 구분하고 선·후순위 접수 조건, 자격 기준일, 가점 변경 내용을 반영.'
}
(OUT / 'article-detail.json').write_text(json.dumps(detail, ensure_ascii=False, indent=2), encoding='utf-8')
(OUT / 'REVIEW.md').write_text(
    '# 검수\n\n'
    '7장 1080×1350. 표지 70px, 안전영역 준수. 기사 원문 전체 확인. 기사 내 SH 사옥 전경을 표지에만 사용. '
    '공가와 예비입주자 모집을 구분하고, 선순위 200% 초과 시 후순위 미접수 조건과 가점 변경을 반영. '
    '캡션 전략: v2 (영향 중심 첫 문단, 해시태그 5개, 선택적 비강요형 질문). 원문 URL 없음. 게시 요청 없음.\n',
    encoding='utf-8'
)

preview = Image.new('RGB', (1080, 676), NAVY)
for i in range(7):
    card = Image.open(OUT / f'{i + 1:02d}.png').resize((270, 338))
    preview.paste(card, ((i % 4) * 270, (i // 4) * 338))
preview.save(OUT / 'preview.jpg', quality=95)

with zipfile.ZipFile(OUT / 'carousel-7slides.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for path in sorted(OUT.glob('*.png')):
        z.write(path, path.name)
    z.write(OUT / 'caption.txt', 'caption.txt')

print(OUT)
