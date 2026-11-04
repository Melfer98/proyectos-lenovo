import assert from 'node:assert/strict';
import {summarizeSales} from './analytics.mjs';
const result=summarizeSales([
{seller:'Ana',seller_email:'ana@example.com',kit:'KT283XSV96',mpn:'82X700GCGJ',quantity:2,unit_price:'499.00'},
{seller:'Ana',seller_email:'otra@example.com',kit:'KT283XSV97',mpn:'82XM016KGJ',quantity:1,unit_price:'559.00'},
{seller:'ANA',seller_email:' ANA@example.com ',kit:'KT284XSV13',mpn:'ZAF10147PA',quantity:3,unit_price:'119.00'}
],[{kit:'KT284XSV14',mpn:'ZAF00113PA',name:'Tab One'}]);
assert.equal(result.totalCents,191400);
assert.equal(result.sellers.length,2);
assert.equal(result.sellers[0].quantity,5);
assert.equal(result.sellers[0].cents,135500);
assert.equal(result.kits.find(k=>k.kit==='KT284XSV14').cents,0);
assert.equal(result.kits.reduce((sum,k)=>sum+k.cents,0),result.totalCents);
assert.equal(result.sellers.reduce((sum,k)=>sum+k.cents,0),result.totalCents);
assert.equal(summarizeSales([]).totalCents,0);
assert.throws(()=>summarizeSales([{quantity:0,unit_price:499}]));
console.log('Verified total, seller identity, kit quantities, unsold kits, and empty state.');
