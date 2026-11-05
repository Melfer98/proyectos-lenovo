import assert from 'node:assert/strict';
const elements=new Map();
function element(id){if(!elements.has(id))elements.set(id,{id,value:'',hidden:false,disabled:false,textContent:'',innerHTML:'',reportValidity:()=>true,replaceChildren(){this.innerHTML='';}});return elements.get(id);}
globalThis.document={getElementById:element,hidden:false,addEventListener(){}};
globalThis.window={PROJECT_CONFIG:{supabaseUrl:'https://test.invalid',supabaseKey:'test-key'}};
globalThis.setInterval=()=>0;
let pages=0,fail=false;
globalThis.fetch=async url=>{
 let data,status=200;
 if(url.includes('grant_type=password'))data={access_token:'test-token',refresh_token:'test-refresh',expires_in:3600,user:{id:'test-user'}};
 else if(url.includes('/project_staff'))data=[{user_id:'test-user'}];
 else if(url.includes('/market_fest_sales')){if(fail)throw Error('Offline');const second=url.includes('id=gt.');pages++;data=Array.from({length:second?1:1000},(_,i)=>({id:String((second?1000:0)+i).padStart(5,'0'),seller:'<img src=x>',seller_email:'test@example.com',kit:'KT283XSV96',mpn:'82X700GCGJ',quantity:1,unit_price:'499.00'}));}
 else if(url==='../products.json')data=[{kit:'KT283XSV96',mpn:'82X700GCGJ',name:'IdeaPad Slim 3'}];
 else if(url.includes('/logout'))data={};else throw Error('Unexpected endpoint '+url);
 return {ok:status===200,status,json:async()=>data};
};
await import('./report.js');
element('email').value='test@example.com';element('password').value='test-only';
await element('login').onsubmit({preventDefault(){}});
assert.equal(pages,2);assert.equal(element('dashboard').hidden,false);assert.equal(element('total').textContent,'$499,499.00');assert.match(element('sellers').innerHTML,/&lt;img src=x&gt;/);assert.equal(element('password').value,'');
fail=true;element('refresh').onclick();await new Promise(r=>setTimeout(r,10));assert.match(element('reportMessage').textContent,/No se pudieron/);assert.equal(element('total').textContent,'$499,499.00');
element('logout').onclick();assert.equal(element('dashboard').hidden,true);assert.equal(element('total').textContent,'—');assert.equal(element('sellers').innerHTML,'');
console.log('Verified protected report flow, 1,001 rows, escaped names, fetch failure, and logout clearing.');
