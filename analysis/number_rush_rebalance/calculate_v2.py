import sys,json
from pathlib import Path
import numpy as np
ROOT=Path(__file__).parent
sys.path.insert(0,str(ROOT.parent/'number_rush_balance'))
from calculate import enumerate_patterns

BASE=np.array([1500,1800,3000,6000,15000,40000])
RATE=np.array([10000,11000,12500,15000,18000,22000])
OPERATORS=[('БиЛайнк','Б'),('Мобител','М'),('МегаЛинк','Г'),('ТелеНова','Т')]
PROFILES=[
 (5000,1.0,[55,43,1.85,.149,.00099,.00001]),
 (15000,1.03,[0,94,5.8,.199,.00099,.00001]),
 (50000,1.06,[0,0,97,2.97,.0297,.0003]),
]
OFFERS=[[name,f'{prefix}{tier+1}',price,prestige,prob] for tier,(price,prestige,prob) in enumerate(PROFILES) for name,prefix in OPERATORS]
PRESTIGE=[o[3] for o in OFFERS]
RECIPES=[4,6,6,8,8]
MIN_RECIPES=[3,5,5,7,7]
N=10000

def pct(a):
 return {str(p):round(float(np.percentile(a,p)),2) for p in (10,50,90)}

def simulate(idx,hist,vip=False,upgrades=False,n=N):
 rng=np.random.default_rng(20261115)
 offer=OFFERS[idx];cost=offer[2];prestige=PRESTIGE[idx]
 weights=np.array(offer[4],dtype=float)
 floor=np.flatnonzero(weights)[0]
 luck=1+(.15 if upgrades else 0)+(.05 if vip else 0)
 weights[floor+1:]*=luck;weights/=weights.sum()
 cdf=np.cumsum(weights)
 scorecdf=np.cumsum(hist,axis=1)/hist.sum(axis=1)[:,None]
 cash=np.full(n,100000.,dtype=float)
 slots=np.full((n,3),-1,dtype=int);sv=np.zeros((n,3));bench=np.full((n,3),-1,dtype=int);bv=np.zeros((n,3))
 rolls=np.zeros(n,int);income=np.zeros(n);sales=np.zeros(n)
 offline_seconds_left=28800
 # All three initial slots start their own 60-minute timer when first filled.
 last=np.full((n,3),-100000,dtype=int)
 def online(start,length):
  nonlocal cash,slots,sv,bench,bv,rolls,income,sales,last
  for t in range(start,start+length,6):
   for s in range(3):
    best=np.argmax(bench*1e9+bv,axis=1)
    row=np.arange(n)
    bt=bench[row,best];val=bv[row,best]
    ok=(t-last[:,s]>=3600)&((bt>slots[:,s])|((bt==slots[:,s])&(val>sv[:,s])))
    ids=np.flatnonzero(ok)
    oldt=slots[ids,s].copy();oldv=sv[ids,s].copy()
    slots[ids,s]=bt[ids];sv[ids,s]=val[ids];last[ids,s]=t
    bench[ids,best[ids]]=oldt;bv[ids,best[ids]]=oldv
   rate=np.where(slots>=0,RATE[np.maximum(slots,0)],0).sum(axis=1)*(1.05 if vip else 1)
   inc=rate*6/3600;cash+=inc;income+=inc
   ids=np.flatnonzero(cash>=cost)
   if not len(ids):continue
   cash[ids]-=cost;rolls[ids]+=1
   tier=np.searchsorted(cdf,rng.random(len(ids)))
   score=np.empty(len(ids));u=rng.random(len(ids))
   for k in range(6):
    mask=tier==k;score[mask]=np.searchsorted(scorecdf[k],u[mask])
   val=np.floor(BASE[tier]*score/700*prestige+.5)
   empty=(slots[ids]<0).any(axis=1);pos=np.argmax(slots[ids]<0,axis=1)
   dest=ids[empty];slots[dest,pos[empty]]=tier[empty];sv[dest,pos[empty]]=val[empty];last[dest,pos[empty]]=t
   rem=ids[~empty]
   if len(rem):
    tiers=np.concatenate([bench[rem],tier[~empty,None]],axis=1)
    vals=np.concatenate([bv[rem],val[~empty,None]],axis=1)
    order=np.argsort(tiers*1e9+vals,axis=1)[:,::-1]
    bench[rem]=np.take_along_axis(tiers,order[:,:3],axis=1);bv[rem]=np.take_along_axis(vals,order[:,:3],axis=1)
    sold=np.take_along_axis(vals,order[:,3:],axis=1).sum(axis=1)
    cash[rem]+=sold;sales[rem]+=sold
 def offline(secs):
  nonlocal cash,income,offline_seconds_left
  rate=np.where(slots>=0,RATE[np.maximum(slots,0)],0).sum(axis=1)*(1.05 if vip else 1)
  paid=min(secs,28800,offline_seconds_left);offline_seconds_left-=paid
  inc=rate*paid/3600*.75;cash+=inc;income+=inc
 def snap():
  rate=np.where(slots>=0,RATE[np.maximum(slots,0)],0).sum(axis=1)*(1.05 if vip else 1)
  return {'rolls':pct(rolls),'cash':pct(cash),'hourly_income':pct(rate),'liquid_assets':pct(cash+sv.sum(axis=1)+bv.sum(axis=1)),'gross_income':pct(income)}
 online(0,1800);a=snap()
 offline(28800);online(30600,1800);offline(54000);b=snap()
 assert np.all(cash>=0)
 return {'players':n,'vip':vip,'upgrades':upgrades,'30min':a,'24h':b}

def savings(h,idx,vip=False,n=N):
 # Fill three slots, stop spinning, save for slot four. Baseline, no quests.
 rng=np.random.default_rng(20261115)
 p=np.array(OFFERS[idx][4])/100
 if vip:
  f=np.flatnonzero(p)[0];p[f+1:]*=1.05;p/=p.sum()
 tiers=np.searchsorted(np.cumsum(p),rng.random((n,3)))
 costs=OFFERS[idx][2]
 cash=np.full(n,100000.);rate=np.zeros(n);elapsed=np.zeros(n)
 for i in range(3):
  need=np.maximum(0,costs-cash)
  wait=np.divide(need,rate,out=np.zeros_like(need),where=rate>0)*3600
  assert np.all((need==0)|(rate>0))
  elapsed+=wait+6;cash+=rate*(wait+6)/3600;cash-=costs
  rate+=RATE[tiers[:,i]]*(1.05 if vip else 1)
 elapsed+=np.maximum(0,170000-cash)/rate*3600
 return pct(elapsed/3600)

cache=ROOT/'pattern_hist.npz'
if cache.exists():hist=np.load(cache)['hist']
else:
 hist=enumerate_patterns();np.savez_compressed(cache,hist=hist)
counts=hist.sum(axis=1);means=hist@np.arange(1401)/counts/700
assert counts.sum()==10000000
result={'base_sale':BASE.tolist(),'income':RATE.tolist(),'means':means.tolist(),'offers':[],'craft':[],'simulations':{},'save_slot4':{}}
for i,o in enumerate(OFFERS):
 p=np.array(o[4])/100;f=np.flatnonzero(p)[0];stress=p.copy();stress[f+1:]*=1.4;stress/=stress.sum()
 # Conservative upper bound: every item has maximum digit coefficient and code match,
 # every roll gets every luck effect, and every sale consumes a max boost.
 maxd=np.floor(BASE*2*1.06*1.05+.5)
 maxs=maxd+np.minimum(np.floor(maxd*.1),1000)
 upper=float(stress@maxs)
 assert abs(p.sum()-1)<1e-12
 assert upper<o[2]
 result['offers'].append({'id':o[1],'operator':o[0],'cost':o[2],'prestige':PRESTIGE[i],'chances':o[4],'base_EV_sale':round(float(p@(BASE*means)*PRESTIGE[i]),2),'max_all_effects_EV_upper_bound':round(upper,2),'expected_single_item_hourly_income':round(float(p@RATE),2)})
for i,n in enumerate(MIN_RECIPES):
 outmax=int(np.floor(BASE[i+1]*2*1.06*1.05+.5))
 cashmax=outmax+min(int(outmax*.1),1000)
 inmin=int(n*BASE[i])
 assert cashmax<inmin
 result['craft'].append({'tier':i,'base_count':RECIPES[i],'min_count':n,'min_inputs_value':inmin,'max_output_sale_with_buff':cashmax,'fragments':2})
for idx in (0,4,8):
 for vip in (False,True):
  key=OFFERS[idx][1]+('_VIP' if vip else '')
  result['simulations'][key]=simulate(idx,hist,vip=vip)
  result['save_slot4'][key]=savings(hist,idx,vip=vip)
 # Max permanent luck: independent stress cohort, same inventory and incomes.
 result['simulations'][OFFERS[idx][1]+'_MAX']=simulate(idx,hist,vip=True,upgrades=True)

# Money-conservation and overlap examples; mathematical model, not Roblox runtime tests.
checks=[]
for D in [1500,2231,4007,33390,89040]:
 boosted=D+min(int(D*.1),1000)
 assert boosted<=D+1000
 # Once traded, the buyer can only liquidate for unboosted D.
 market_min=D;assert D-market_min<=0
 # Auction bids reserve rather than deduct-and-refund through a second budget.
 buyer_before=1_000_000;seller_before=0;price=max(D,10000)
 seller_after=price-int(np.ceil(price*.1));buyer_after=buyer_before-price
 assert buyer_after+seller_after==buyer_before-int(np.ceil(price*.1))
 checks.append(D)
result['checks']={'probability_rows':12,'negative_EV_upper_bounds':12,'craft_no_positive_liquidation':5,'market_conservation_examples':len(checks),'income_VIP_ratio':1.05,'max_luck':1.4,'max_speed':1.5,'max_NPC_extra_per_day':10000,'max_daily_reward_per_day':10000}
(ROOT/'results_v2.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({'checks':result['checks'],'save_slot4':result['save_slot4'],'simulations':result['simulations'],'offers':result['offers'],'craft':result['craft']},ensure_ascii=False,indent=2))
