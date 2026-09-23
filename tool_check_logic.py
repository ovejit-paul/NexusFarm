# Python port of the livestock and ledger logic, run against the Dart tests' expectations.
# Useful when no Dart SDK is at hand. `flutter test` remains the real check.
# Line-for-line port of the Dart logic, run against the Dart tests' expectations.
from datetime import date, timedelta as td
D=lambda y,m,d: date(y,m,d)
addDays=lambda d,n: d+td(n); between=lambda a,b:(b-a).days
DUE_SOON=14
SPECS={  # (species,type,name): (interval, firstAt)
 ('cattle','vaccination','FMD (foot-and-mouth)'):(180,120),
 ('cattle','vaccination','Anthrax'):(365,180),
 ('cattle','deworming','Deworming'):(120,60),
 ('chicken','vaccination','Gumboro (IBD)'):(0,14),
}
def matches(spec,e):
    sp,ty,nm=spec
    return e['type']=='deworming' if ty=='deworming' else (e['type']==ty and e['name']==nm)
def schedule(animal,events,on,name):
    spec=[s for s in SPECS if s[0]==animal['species'] and s[2]==name][0]
    interval,first=SPECS[spec]
    last=None
    for e in events:
        if e['animal']==animal['id'] and matches(spec,e) and (last is None or e['date']>last['date']): last=e
    if last and interval==0: return ('completed',None,last['date'])
    due=None
    if last: due=addDays(last['date'],interval)
    elif animal.get('birth') and first is not None: due=addDays(animal['birth'],first)
    if due is None: return ('noRecord',None,None)
    n=between(on,due)
    return ('overdue' if n<0 else 'dueSoon' if n<=DUE_SOON else 'upToDate', due, last['date'] if last else None)
def holds(animal,events,on,daily):
    out={}
    for p in [daily,'meat']:
        best=None
        for e in events:
            if e['animal']!=animal['id'] or e['date']>on: continue
            days=e.get(p,0)
            if days<=0: continue
            safe=addDays(e['date'],days)
            if not on<safe: continue
            if best is None or safe>best[0]: best=(safe,e['id'])
        if best: out[p]=best
    return out
def spray_hold(t,on): return t['phi']>0 and not on<t['date'] and on<addDays(t['date'],t['phi'])

ok=0; fail=0
def check(label,got,want):
    global ok,fail
    if got==want: ok+=1
    else: fail+=1; print("FAIL",label,"got",got,"want",want)

cow={'id':'cow1','species':'cattle'}; flock={'id':'flock1','species':'chicken'}
v=lambda a,n,d:{'id':f'{a}{n}{d}','animal':a,'type':'vaccination','name':n,'date':d}
F='FMD (foot-and-mouth)'
ev=[v('cow1',F,D(2026,3,1))]
check('due date', schedule(cow,ev,D(2026,6,1),F)[:2], ('upToDate',D(2026,8,28)))
check('due soon 8/20', schedule(cow,ev,D(2026,8,20),F)[0],'dueSoon')
check('due day itself', schedule(cow,ev,D(2026,8,28),F)[0],'dueSoon')
check('overdue', schedule(cow,ev,D(2026,9,10),F)[0],'overdue')
check('latest wins', schedule(cow,[v('cow1',F,D(2025,9,1)),v('cow1',F,D(2026,3,1))],D(2026,6,1),F)[2],D(2026,3,1))
check('from birth', schedule({**cow,'birth':D(2026,1,1)},[],D(2026,3,1),F)[1],D(2026,5,1))
check('no record', schedule(cow,[],D(2026,3,1),F)[0],'noRecord')
check('name only', schedule(cow,[v('cow1','Anthrax',D(2026,3,1))],D(2026,3,5),F)[0],'noRecord')
check('other animal', schedule(cow,[v('x',F,D(2026,3,1))],D(2026,3,5),F)[0],'noRecord')
w={'id':'w','animal':'cow1','type':'deworming','name':'Albendazole','date':D(2026,3,1)}
check('any dewormer', schedule(cow,[w],D(2026,3,5),'Deworming')[1:], (D(2026,6,29),D(2026,3,1)))
check('one-off done', schedule(flock,[v('flock1','Gumboro (IBD)',D(2026,2,1))],D(2026,9,1),'Gumboro (IBD)')[0],'completed')

t1={'id':'t1','animal':'cow1','date':D(2026,9,1),'milk':7,'meat':28}
h=holds(cow,[t1],D(2026,9,5),'milk')
check('milk safe', h['milk'][0], D(2026,9,8)); check('days left', between(D(2026,9,5),h['milk'][0]),3)
check('meat safe', h['meat'][0], D(2026,9,29))
check('held 9/7', 'milk' in holds(cow,[t1],D(2026,9,7),'milk'), True)
check('free 9/8', 'milk' in holds(cow,[t1],D(2026,9,8),'milk'), False)
check('meat 9/8', 'meat' in holds(cow,[t1],D(2026,9,8),'milk'), True)
check('day of treatment', 'milk' in holds(cow,[t1],D(2026,9,1),'milk'), True)
check('future treatment', 'milk' in holds(cow,[t1],D(2026,8,30),'milk'), False)
t2={'id':'t2','animal':'cow1','date':D(2026,9,3),'milk':4}
check('longer wins', holds(cow,[t1,t2],D(2026,9,4),'milk')['milk'], (D(2026,9,8),'t1'))
p={'id':'p','animal':'flock1','date':D(2026,9,1),'eggs':10}
check('eggs', holds(flock,[p],D(2026,9,5),'eggs'), {'eggs':(D(2026,9,11),'p')})

spray={'date':D(2026,9,10),'phi':7}
check('spray 9/16', spray_hold(spray,D(2026,9,16)),True)
check('spray 9/17', spray_hold(spray,D(2026,9,17)),False)
check('spray 9/9 before', spray_hold(spray,D(2026,9,9)),False)
check('spray 9/10', spray_hold(spray,D(2026,9,10)),True)
# hold counts from farm_data_test sample: cow treated 9/1 milk7 meat28, spray 9/10 phi7
def count(on): return len(holds({'id':'a1','species':'cattle'},[{**t1,'animal':'a1'}],on,'milk'))+(1 if spray_hold(spray,on) else 0)
check('count 9/5', count(D(2026,9,5)),2); check('count 9/12', count(D(2026,9,12)),2); check('count 10/1', count(D(2026,10,1)),0)

L=[('i','cattle',1000,D(2026,9,1)),('e','cattle',300,D(2026,9,15)),('e','crops',250,D(2026,9,30)),('i','crops',5000,D(2026,10,1))]
def summ(f=None,t=None):
    inc=exp=0; n=0; cat={}
    for k,c,a,d in L:
        if f and d<f: continue
        if t and d>t: continue
        n+=1; cat.setdefault(c,[0,0])
        if k=='i': inc+=a; cat[c][0]+=a
        else: exp+=a; cat[c][1]+=a
    return n,inc,exp,inc-exp,{c:v[0]-v[1] for c,v in cat.items()}
check('month', summ(D(2026,9,1),D(2026,9,30)), (3,1000,550,450,{'cattle':700,'crops':-250}))
check('all net', summ()[3], 5450)
print(f"{ok} passed, {fail} failed")
