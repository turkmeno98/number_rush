import json
from pathlib import Path
import numpy as np

OUT = Path(__file__).parent
NAMES = ['Обычный','Необычный','Редкий','Эпический','Легендарный','Исключительный']
DIGITS = np.array([200,165,120,130,100,140,110,190,180,150])
BASE = np.array([500,1000,3000,10000,100000,1000000])
INCOME = np.array([10000,30000,90000,270000,810000,2430000])
OFFERS = [
 ['БиЛайнк','Б1',5000,1.00,[55,43,1.85,.149,.00099,.00001]],
 ['Мобител','М1',6000,1.03,[50,47.5,2.3,.199,.00099,.00001]],
 ['МегаЛинк','Г1',7000,1.06,[45,52,2.75,.249,.00099,.00001]],
 ['ТелеНова','Т1',8000,1.09,[40,56.5,3.2,.299,.00099,.00001]],
 ['БиЛайнк','Б2',15000,1.12,[0,94,5.8,.199,.00099,.00001]],
 ['Мобител','М2',18000,1.15,[0,90,9.7,.299,.00099,.00001]],
 ['МегаЛинк','Г2',20000,1.18,[0,86,13.6,.399,.00099,.00001]],
 ['ТелеНова','Т2',25000,1.21,[0,80,19.5,.499,.00099,.00001]],
 ['БиЛайнк','Б3',35000,1.24,[0,0,99.5,.49,.0099,.0001]],
 ['Мобител','М3',40000,1.26,[0,0,99,.99,.0099,.0001]],
 ['МегаЛинк','Г3',45000,1.28,[0,0,98,1.98,.0198,.0002]],
 ['ТелеНова','Т3',50000,1.30,[0,0,97,2.97,.0297,.0003]],
]

def enumerate_patterns():
 hist=np.zeros((6,1401),dtype=np.int64)
 for start in range(0,10_000_000,250_000):
  n=np.arange(start,start+250_000)
  d=(n[:,None]//(10**np.arange(6,-1,-1)))%10
  def run(k):
   return np.logical_or.reduce([np.all(d[:,i:i+k]==d[:,i:i+1],axis=1) for i in range(8-k)])
  def seq(k):
   return np.logical_or.reduce([np.all(np.diff(d[:,i:i+k],axis=1)==1,axis=1)|np.all(np.diff(d[:,i:i+k],axis=1)==-1,axis=1) for i in range(8-k)])
  exceptional=run(7)
  legendary=run(6)|seq(7)|(np.all(d[:,2:]==d[:,:-2],axis=1)&(d[:,0]!=d[:,1]))
  epic=np.all(d==d[:,::-1],axis=1)|run(5)|(np.all(d[:,1:4]==d[:,4:7],axis=1)&~np.all(d[:,1:4]==d[:,1:2],axis=1))
  pairs=(d[:,1]==d[:,2])&(d[:,3]==d[:,4])&(d[:,5]==d[:,6])&(d[:,1]!=d[:,3])&(d[:,1]!=d[:,5])&(d[:,3]!=d[:,5])
  rare=run(4)|seq(5)|pairs|((d[:,3]==d[:,5])&(d[:,4]==d[:,6])&(d[:,3]!=d[:,4]))
  uncommon=run(2)|seq(3)|((d[:,3]==d[:,6])&(d[:,4]==d[:,5]))
  tier=np.select([exceptional,legendary,epic,rare,uncommon],[5,4,3,2,1],default=0)
  score=DIGITS[d].sum(axis=1)
  hist+=np.bincount(tier*1401+score,minlength=6*1401).reshape(6,1401)
 return hist

def percentile(a):
 return {str(p):round(float(np.percentile(a,p)),2) for p in (10,50,90)}

def simulate(offer,hist,seed=20261115,n=10000):
 rng=np.random.default_rng(seed)
 _,_,cost,prestige,weights=offer
 prob=np.array(weights)/100
 cdf=np.cumsum(prob)
 scorecdf=np.cumsum(hist,axis=1)/hist.sum(axis=1)[:,None]
 cash=np.full(n,100000.,dtype=float)
 slot=np.full((n,3),-1,dtype=int)
 sval=np.zeros((n,3))
 bench=np.full((n,3),-1,dtype=int)
 bval=np.zeros((n,3))
 rolls=np.zeros(n,dtype=int)
 income_earned=np.zeros(n)
 sales=np.zeros(n)
 def online(start,seconds):
  nonlocal cash,slot,sval,bench,bval,rolls,income_earned,sales
  for t in range(start,start+seconds,6):
   if t%3600==0 or t==start:
    tiers=np.concatenate([slot,bench],axis=1)
    vals=np.concatenate([sval,bval],axis=1)
    order=np.argsort(tiers*1e9+vals,axis=1)[:,::-1]
    slot=np.take_along_axis(tiers,order[:,:3],axis=1)
    sval=np.take_along_axis(vals,order[:,:3],axis=1)
    bench=np.take_along_axis(tiers,order[:,3:],axis=1)
    bval=np.take_along_axis(vals,order[:,3:],axis=1)
   rate=np.where(slot>=0,INCOME[np.maximum(slot,0)],0).sum(axis=1)
   earned=rate*6/3600
   cash+=earned; income_earned+=earned
   ids=np.flatnonzero(cash>=cost)
   if len(ids)==0: continue
   cash[ids]-=cost;rolls[ids]+=1
   tier=np.searchsorted(cdf,rng.random(len(ids)))
   u=rng.random(len(ids));score=np.empty(len(ids))
   for k in range(6):
    mask=tier==k
    score[mask]=np.searchsorted(scorecdf[k],u[mask])
   value=np.floor(BASE[tier]*score/700*prestige+.5)
   empty=(slot[ids]<0).any(axis=1)
   pos=np.argmax(slot[ids]<0,axis=1)
   slot[ids[empty],pos[empty]]=tier[empty]
   sval[ids[empty],pos[empty]]=value[empty]
   rem=ids[~empty];rt=tier[~empty];rv=value[~empty]
   if len(rem):
    tiers=np.concatenate([bench[rem],rt[:,None]],axis=1)
    vals=np.concatenate([bval[rem],rv[:,None]],axis=1)
    order=np.argsort(tiers*1e9+vals,axis=1)[:,::-1]
    bench[rem]=np.take_along_axis(tiers,order[:,:3],axis=1)
    bval[rem]=np.take_along_axis(vals,order[:,:3],axis=1)
    sold=np.take_along_axis(vals,order[:,3:],axis=1).sum(axis=1)
    cash[rem]+=sold;sales[rem]+=sold
 def offline(seconds):
  nonlocal cash,income_earned
  rate=np.where(slot>=0,INCOME[np.maximum(slot,0)],0).sum(axis=1)
  earned=rate*min(seconds,8*3600)/3600*.75
  cash+=earned;income_earned+=earned
 def snapshot():
  rate=np.where(slot>=0,INCOME[np.maximum(slot,0)],0).sum(axis=1)
  assets=cash+sval.sum(axis=1)+bval.sum(axis=1)
  return {'rolls':percentile(rolls),'cash':percentile(cash),'hourly_income':percentile(rate),'cash_plus_liquidation':percentile(assets),'income_earned':percentile(income_earned),'sales':percentile(sales)}
 online(0,1800)
 thirty=snapshot()
 offline(8*3600)
 online(30600,1800)
 offline(15*3600)
 day=snapshot()
 assert np.all(cash>=0)
 return {'n':n,'seed':seed,'30min':thirty,'24h':day}

if __name__=='__main__':
 hist=enumerate_patterns()
 counts=hist.sum(axis=1)
 assert counts.tolist()==[4764478,5078404,134600,22230,278,10]
 mean=hist@np.arange(1401)/counts/700
 result={'counts':counts.tolist(),'mean_digit_multiplier':mean.tolist(),'offers':[]}
 for offer in OFFERS:
  assert abs(sum(offer[4])-100)<1e-8
  prob=np.array(offer[4])/100
  ev=float(prob@(BASE*mean)*offer[3])
  minimum=np.flatnonzero(prob)[0]
  high=prob[minimum+1:].sum()
  stressed=high*4/(1-high+high*4)
  stressed_p=prob.copy();stressed_p[minimum+1:]*=4;stressed_p/=stressed_p.sum()
  stress_ev=float(stressed_p@(BASE*mean)*offer[3]*4.5)
  result['offers'].append({'operator':offer[0],'code_id':offer[1],'cost':offer[2],'prestige':offer[3],'percentages':offer[4],'expected_base_sale':round(ev,2),'expected_sale_vip_and_both_max_buffs':round(stress_ev,2),'base_above_floor_percent':high*100,'vip_boost_above_floor_percent':stressed*100})
 result['simulations']={}
 for idx in (0,8,11):
  result['simulations'][OFFERS[idx][1]]=simulate(OFFERS[idx],hist)
 (OUT/'results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
 print(json.dumps(result,ensure_ascii=False,indent=2))
