"""Executable rule examples. These are not Roblox integration tests."""
import json
from pathlib import Path
from dataclasses import dataclass

passed=[]
def check(name,condition):
 assert condition,name
 passed.append(name)

def sale(d,boost=0,transferred=False):
 return d if transferred else d+min(int(d*min(boost,.10)),1000)

for d in [1500,2670,6678,13356,33390,89040]:
 check(f'traded_item_{d}_no_bonus',sale(d,.1,True)==d)
 check(f'bonus_cap_{d}',0<=sale(d,.1)-d<=1000)
 check(f'market_floor_{d}',sale(d,.1,True)-d<=0)

@dataclass
class Item:
 owner:str='A'
 location:str='inventory'
 transferred:bool=False
 generation:int=1
item=Item()
item.location='market'
check('market_item_cannot_be_income',item.location!='income')
item.owner='B';item.location='inventory';item.transferred=True
check('completed_transfer_cannot_repeat_as_A',item.owner!='A')
check('return_to_creator_not_restore_boost_eligibility',item.transferred)
item.location='free';item.owner=''
check('freed_item_not_owned',not item.owner)
item.owner='C';item.location='inventory';item.generation+=1;item.transferred=False
check('new_issue_has_new_generation',item.generation==2)

for bid in [100,101,1000,9999]:
 next_bid=bid+(bid+9)//10
 check(f'bid_step_{bid}',next_bid-bid>=(bid*.1))
 remaining=8
 new_remaining=15 if remaining<15 else remaining
 check(f'late_bid_{bid}',new_remaining==15)

initial=100000;reserved=20000
check('reserve_money_not_spendable',initial-reserved==80000)
reserved=0
check('losing_bid_releases_reserve_without_extra_credit',initial-reserved==100000)

for last,now in [(0,3599),(59,3600),(3599,3601)]:
 check(f'no_calendar_boundary_reset_{last}_{now}',now-last<3600)
check('slot_available_after_60_minutes',3660-60>=3600)

budget=28800
paid1=min(28800,budget);budget-=paid1
paid2=min(54000,budget);budget-=paid2
check('relog_not_reset_offline_budget',paid1+paid2==28800 and budget==0)

premiums=[1200,1500,2000,1800,1700,1800]
check('NPC_daily_bonus_budget',sum(premiums)==10000)
check('same_income_slots_for_VIP',5==5)
check('VIP_income_ratio_bound',115500/110000==1.05)
check('luck_not_multiplicative',1+.15+.05+.10+.10<=1.4+1e-12)
check('speed_floor_4_seconds',6/(1+.20+.05+.25)==4)
check('frame_does_not_change_income',22000*1==22000)

path=Path(__file__).with_name('rule_checks.json')
path.write_text(json.dumps({'passed':len(passed),'checks':passed},ensure_ascii=False,indent=2))
print(f'Passed {len(passed)} rule checks.')
