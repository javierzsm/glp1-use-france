const C={navy:'#123149',teal:'#147d86',cyan:'#16a5aa',blue:'#3487b9',purple:'#7c62ad',orange:'#e76f51',muted:'#607580',grid:'#e4ecee'};
const CONFIG={responsive:true,displaylogo:false,modeBarButtonsToRemove:['lasso2d','select2d']};
const BASE={font:{family:'Source Sans 3, sans-serif',color:'#202a30',size:13},paper_bgcolor:'#fff',plot_bgcolor:'#fff',margin:{l:62,r:22,t:28,b:52},hoverlabel:{font:{family:'Source Sans 3, sans-serif'}},xaxis:{gridcolor:C.grid,zeroline:false},yaxis:{gridcolor:C.grid,zeroline:false},legend:{orientation:'h',y:-.18}};
const fmtInt=x=>new Intl.NumberFormat('en-GB',{maximumFractionDigits:0}).format(x);
const fmtRate=x=>new Intl.NumberFormat('en-GB',{minimumFractionDigits:1,maximumFractionDigits:1}).format(x);
const fmtMoney=x=>'€'+(x/1e6).toFixed(1)+'m';
const merge=(a,b)=>({...a,...b,xaxis:{...a.xaxis,...(b.xaxis||{})},yaxis:{...a.yaxis,...(b.yaxis||{})}});
let DATA,GEO;

async function load(){
  try{
    [DATA,GEO]=await Promise.all([fetch('data/dashboard.json').then(r=>r.json()),fetch('data/metropolitan_regions.geojson').then(r=>r.json())]);
    const page=document.body.dataset.page;
    if(page==='overview')overview(); if(page==='national')national(); if(page==='regions')regions(); if(page==='maps')maps();
    window.addEventListener('resize',()=>document.querySelectorAll('.plot').forEach(el=>Plotly.Plots.resize(el)));
  }catch(e){document.querySelector('main').insertAdjacentHTML('afterbegin',`<div class="error">Dashboard data could not be loaded. ${e.message}</div>`)}
}
function line(id,rows,x,y,name,colour=C.teal,extra={}){Plotly.newPlot(id,[{x:rows.map(d=>d[x]),y:rows.map(d=>d[y]),type:'scatter',mode:'lines+markers',name,line:{color:colour,width:3},marker:{size:7},...extra}],merge(BASE,{}),CONFIG)}
function setKpi(id,value,delta=''){const el=document.getElementById(id);el.querySelector('.value').textContent=value;el.querySelector('.delta').textContent=delta}
function regionalRows(year){const a=DATA.regional_annual.filter(d=>+d.study_year===+year);const s=DATA.regional_standardised.filter(d=>+d.study_year===+year);return a.map(x=>({...x,...s.find(y=>String(y.region_code)===String(x.region_code))}));}
function metro(rows){return rows.filter(d=>String(d.region_code)!=='5')}
function colourScale(){return [[0,'#edf6f5'],[.28,'#69bbb9'],[.55,'#08a2a7'],[.78,'#3487b9'],[1,'#7c62ad']]}
function drawMap(id,year,metric='standardised_rate_per_100000',fixed=true){
 const rows=metro(regionalRows(year)); const codes=rows.map(d=>String(d.region_code)); const values=rows.map(d=>+d[metric]);
 const all=metro(DATA.regional_standardised); const universe=metric==='crude_rate_per_100000'?all.map(d=>+d.crude_rate_per_100000):all.map(d=>+d.standardised_rate_per_100000);
 const range=fixed?[Math.min(...universe),Math.max(...universe)]:[Math.min(...values),Math.max(...values)];
 Plotly.newPlot(id,[{type:'choropleth',geojson:GEO,locations:codes,z:values,featureidkey:'properties.analysis_region_code',colorscale:colourScale(),zmin:range[0],zmax:range[1],marker:{line:{color:'#fff',width:1.2}},customdata:rows.map(d=>[d.region_name,d.beneficiaries,d.crude_rate_per_100000,d.standardised_rate_per_100000]),hovertemplate:'<b>%{customdata[0]}</b><br>Beneficiaries: %{customdata[1]:,.0f}<br>Crude rate: %{customdata[2]:,.1f}<br>Standardised rate: %{customdata[3]:,.1f}<extra></extra>',colorbar:{title:'per 100,000',orientation:'h',x:.5,xanchor:'center',y:-.05,len:.72,thickness:14}}],merge(BASE,{geo:{fitbounds:'locations',visible:false,projection:{type:'mercator'}},margin:{l:5,r:5,t:5,b:58}}),CONFIG);
}
function drawRank(id,year,metric='standardised_rate_per_100000'){
 const rows=metro(regionalRows(year)).sort((a,b)=>a[metric]-b[metric]);
 Plotly.newPlot(id,[{type:'bar',orientation:'h',y:rows.map(d=>d.region_name),x:rows.map(d=>d[metric]),marker:{color:rows.map(d=>d[metric]),colorscale:colourScale(),showscale:false},hovertemplate:'%{y}<br>%{x:,.1f} per 100,000<extra></extra>'}],merge(BASE,{margin:{l:180,r:20,t:10,b:45},showlegend:false,xaxis:{title:'Rate per 100,000'}}),CONFIG)
}
function overview(){
 const yearEl=document.getElementById('overview-year');
 function render(){const year=+yearEl.value,n=DATA.national.find(d=>+d.year===year),r=regionalRows(year),mr=metro(r);setKpi('k-beneficiaries',fmtInt(n.beneficiaries),`${n.annual_beneficiary_percentage_change?.toFixed(1)??'—'}% year on year`);setKpi('k-rate',fmtRate(n.beneficiaries_per_100000),'per 100,000 residents');const ra=DATA.regional_annual.filter(d=>+d.study_year===year);setKpi('k-boxes',fmtInt(ra.reduce((s,d)=>s+(+d.boxes||0),0)),'reimbursed boxes');setKpi('k-spend',fmtMoney(ra.reduce((s,d)=>s+(+d.reimbursed_expenditure_eur||0),0)),'nominal reimbursement');setKpi('k-region',mr.sort((a,b)=>b.standardised_rate_per_100000-a.standardised_rate_per_100000)[0].region_name,'highest metropolitan rate');drawMap('overview-map',year);drawRank('overview-rank',year)}
 yearEl.addEventListener('change',render);render();
 const n=DATA.national;Plotly.newPlot('overview-national',[{x:n.map(d=>d.year),y:n.map(d=>d.beneficiaries),name:'Beneficiaries',mode:'lines+markers',line:{color:C.navy,width:3}},{x:n.map(d=>d.year),y:n.map(d=>d.beneficiaries_per_100000),name:'Rate per 100,000',mode:'lines+markers',yaxis:'y2',line:{color:C.teal,width:3}}],merge(BASE,{yaxis:{title:'Beneficiaries',tickformat:',.0f'},yaxis2:{title:'Rate per 100,000',overlaying:'y',side:'right',showgrid:false},legend:{orientation:'h',y:-.2}}),CONFIG);
 const s=DATA.substances;const names=[...new Set(s.map(d=>d.atc_name))];Plotly.newPlot('overview-composition',names.map((name,i)=>({x:s.filter(d=>d.atc_name===name).map(d=>d.year),y:s.filter(d=>d.atc_name===name).map(d=>100*d.box_share),name,type:'scatter',mode:'lines',stackgroup:'one',line:{width:1},fillcolor:[C.blue,C.orange,C.teal,C.purple][i]})),merge(BASE,{yaxis:{title:'Share of boxes (%)',range:[0,100]},hovermode:'x unified'}),CONFIG)
}
function national(){
 const n=DATA.national;const measures={beneficiaries:['Beneficiaries','beneficiaries'],rate:['Rate per 100,000','beneficiaries_per_100000']};const sel=document.getElementById('national-measure');
 function render(){const [label,key]=measures[sel.value];line('national-level',n,'year',key,label,C.navy);const first=n[0][key];Plotly.newPlot('national-index',[{x:n.map(d=>d.year),y:n.map(d=>100*d[key]/first),type:'scatter',mode:'lines+markers',line:{color:C.teal,width:3},hovertemplate:'%{x}: %{y:.1f}<extra></extra>'}],merge(BASE,{yaxis:{title:'Index (2020 = 100)'}}),CONFIG);const changeKey=sel.value==='beneficiaries'?'annual_beneficiary_percentage_change':'annual_rate_percentage_change';Plotly.newPlot('national-change',[{x:n.slice(1).map(d=>d.year),y:n.slice(1).map(d=>d[changeKey]),type:'bar',marker:{color:n.slice(1).map(d=>d[changeKey]),colorscale:colourScale(),showscale:false},text:n.slice(1).map(d=>d[changeKey].toFixed(1)+'%'),textposition:'outside'}],merge(BASE,{yaxis:{title:'Annual change (%)'},showlegend:false}),CONFIG)}sel.addEventListener('change',render);render();
 Plotly.newPlot('national-heat',[{z:[n.map(d=>d.beneficiaries_per_100000),n.map(d=>d.annual_beneficiary_percentage_change)],x:n.map(d=>d.year),y:['Rate per 100,000','Annual beneficiary change (%)'],type:'heatmap',colorscale:colourScale(),hoverongaps:false}],merge(BASE,{margin:{l:180,r:20,t:15,b:45}}),CONFIG);document.getElementById('national-table').innerHTML=table(n,['year','beneficiaries','beneficiaries_per_100000','annual_beneficiary_percentage_change']);
}
function regions(){
 const yearEl=document.getElementById('regions-year'),metricEl=document.getElementById('regions-metric');function render(){const y=+yearEl.value,m=metricEl.value;drawRank('regions-rank',y,m);const rows=metro(regionalRows(y));Plotly.newPlot('regions-adjustment',[{x:rows.map(d=>d.crude_rate_per_100000),y:rows.map(d=>d.standardised_rate_per_100000),text:rows.map(d=>d.region_name),mode:'markers',type:'scatter',marker:{size:11,color:rows.map(d=>d.standardised_rate_per_100000),colorscale:colourScale(),showscale:false},hovertemplate:'<b>%{text}</b><br>Crude %{x:,.1f}<br>Standardised %{y:,.1f}<extra></extra>'}],merge(BASE,{xaxis:{title:'Crude rate'},yaxis:{title:'Standardised rate'},shapes:[{type:'line',x0:700,y0:700,x1:1900,y1:1900,line:{dash:'dot',color:C.muted}}]}),CONFIG)}yearEl.addEventListener('change',render);metricEl.addEventListener('change',render);render();
 const rows=metro(DATA.regional_standardised);const names=[...new Set(rows.map(d=>d.region_name))];const years=[...new Set(rows.map(d=>d.study_year))];Plotly.newPlot('regions-heat',[{z:names.map(n=>years.map(y=>rows.find(d=>d.region_name===n&&+d.study_year===+y)?.standardised_rate_per_100000)),x:years,y:names,type:'heatmap',colorscale:colourScale(),colorbar:{title:'per 100,000'}}],merge(BASE,{margin:{l:190,r:35,t:10,b:45}}),CONFIG);Plotly.newPlot('regions-trends',names.map(n=>{const x=rows.filter(d=>d.region_name===n);return{x:x.map(d=>d.study_year),y:x.map(d=>d.standardised_rate_per_100000),name:n,type:'scatter',mode:'lines',line:{width:1.7}}}),merge(BASE,{yaxis:{title:'Standardised rate per 100,000'},hovermode:'x unified',legend:{orientation:'h',y:-.35,font:{size:10}}}),CONFIG)
}
function maps(){const y=document.getElementById('map-year'),m=document.getElementById('map-metric'),s=document.getElementById('map-scale'),c=document.getElementById('compare-year');function render(){drawMap('map-primary',+y.value,m.value,s.value==='common');drawRank('map-rank',+y.value,m.value);drawMap('map-compare',+c.value,m.value,true)}[y,m,s,c].forEach(el=>el.addEventListener('change',render));render()}
function table(rows,cols){const labels={year:'Year',beneficiaries:'Beneficiaries',beneficiaries_per_100000:'Rate per 100,000',annual_beneficiary_percentage_change:'Annual change (%)'};return `<table><thead><tr>${cols.map(c=>`<th>${labels[c]||c}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${cols.map(c=>`<td>${r[c]==null?'—':typeof r[c]==='number'?new Intl.NumberFormat('en-GB',{maximumFractionDigits:1}).format(r[c]):r[c]}</td>`).join('')}</tr>`).join('')}</tbody></table>`}
document.addEventListener('DOMContentLoaded',load);
