const C={navy:'#123149',teal:'#147d86',cyan:'#16a5aa',blue:'#3487b9',purple:'#7c62ad',orange:'#e76f51',muted:'#607580',grid:'#e4ecee'};
const CONFIG={responsive:true,displaylogo:false,modeBarButtonsToRemove:['lasso2d','select2d']};
const BASE={font:{family:'Source Sans 3, sans-serif',color:'#202a30',size:13},paper_bgcolor:'#fff',plot_bgcolor:'#fff',margin:{l:82,r:38,t:38,b:72},hoverlabel:{font:{family:'Source Sans 3, sans-serif'}},xaxis:{gridcolor:C.grid,zeroline:false,automargin:true},yaxis:{gridcolor:C.grid,zeroline:false,automargin:true},legend:{orientation:'h',y:-.2}};
const fmtInt=x=>new Intl.NumberFormat('en-GB',{maximumFractionDigits:0}).format(x);
const fmtRate=x=>new Intl.NumberFormat('en-GB',{minimumFractionDigits:1,maximumFractionDigits:1}).format(x);
const fmtMoney=x=>'€'+(x/1e6).toFixed(1)+'m';
const merge=(a,b)=>({...a,...b,xaxis:{...a.xaxis,...(b.xaxis||{})},yaxis:{...a.yaxis,...(b.yaxis||{})}});
let DATA,GEO;

async function load(){
  try{
    [DATA,GEO]=await Promise.all([fetch('data/dashboard.json').then(r=>r.json()),fetch('data/metropolitan_regions.geojson').then(r=>r.json())]);
    const page=document.body.dataset.page;
    if(page==='overview')overview(); if(page==='national')national(); if(page==='regions')regions(); if(page==='maps')maps(); if(page==='substances')substances(); if(page==='demographics')demographics(); if(page==='profiles')profiles(); if(page==='overseas')overseas(); if(page==='explorer')explorer();
    addFigureCaptions();
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
 const n=DATA.national;Plotly.newPlot('overview-national',[{x:n.map(d=>d.year),y:n.map(d=>d.beneficiaries),name:'Beneficiaries',mode:'lines+markers',line:{color:C.navy,width:3}},{x:n.map(d=>d.year),y:n.map(d=>d.beneficiaries_per_100000),name:'Rate per 100,000',mode:'lines+markers',yaxis:'y2',line:{color:C.teal,width:3}}],merge(BASE,{margin:{l:105,r:135,t:38,b:105},yaxis:{title:{text:'Beneficiaries',standoff:18},tickformat:',.0f',automargin:true},yaxis2:{title:{text:'Rate per 100,000',standoff:20},overlaying:'y',side:'right',showgrid:false,automargin:true},legend:{orientation:'h',x:0,y:-.24}}),CONFIG);
 const s=DATA.substances;const names=[...new Set(s.map(d=>d.atc_name))];Plotly.newPlot('overview-composition',names.map((name,i)=>({x:s.filter(d=>d.atc_name===name).map(d=>d.year),y:s.filter(d=>d.atc_name===name).map(d=>100*d.box_share),name,type:'scatter',mode:'lines',stackgroup:'one',line:{width:1},fillcolor:[C.blue,C.orange,C.teal,C.purple][i]})),merge(BASE,{yaxis:{title:'Share of boxes (%)',range:[0,100]},hovermode:'x unified'}),CONFIG)
}
function national(){
 const n=DATA.national;const measures={beneficiaries:['Beneficiaries','beneficiaries'],rate:['Rate per 100,000','beneficiaries_per_100000']};const sel=document.getElementById('national-measure');
 function render(){const [label,key]=measures[sel.value];line('national-level',n,'year',key,label,C.navy);const first=n[0][key];Plotly.newPlot('national-index',[{x:n.map(d=>d.year),y:n.map(d=>100*d[key]/first),type:'scatter',mode:'lines+markers',line:{color:C.teal,width:3},hovertemplate:'%{x}: %{y:.1f}<extra></extra>'}],merge(BASE,{yaxis:{title:'Index (2020 = 100)'}}),CONFIG);const changeKey=sel.value==='beneficiaries'?'annual_beneficiary_percentage_change':'annual_rate_percentage_change',values=n.slice(1).map(d=>d[changeKey]);Plotly.newPlot('national-change',[{x:n.slice(1).map(d=>d.year),y:values,type:'bar',cliponaxis:false,marker:{color:values,colorscale:colourScale(),showscale:false},text:values.map(d=>d.toFixed(1)+'%'),textposition:'outside'}],merge(BASE,{margin:{l:90,r:45,t:65,b:65},yaxis:{title:'Annual change (%)',range:[0,Math.max(...values)*1.22],automargin:true},showlegend:false}),CONFIG)}sel.addEventListener('change',render);render();
 document.getElementById('national-table').innerHTML=table(n,['year','beneficiaries','beneficiaries_per_100000','annual_beneficiary_percentage_change']);
}
function regions(){
 const yearEl=document.getElementById('regions-year'),metricEl=document.getElementById('regions-metric');function render(){const y=+yearEl.value,m=metricEl.value;drawRank('regions-rank',y,m);const rows=metro(regionalRows(y));Plotly.newPlot('regions-adjustment',[{x:rows.map(d=>d.crude_rate_per_100000),y:rows.map(d=>d.standardised_rate_per_100000),text:rows.map(d=>d.region_name),mode:'markers',type:'scatter',marker:{size:11,color:rows.map(d=>d.standardised_rate_per_100000),colorscale:colourScale(),showscale:false},hovertemplate:'<b>%{text}</b><br>Crude %{x:,.1f}<br>Standardised %{y:,.1f}<extra></extra>'}],merge(BASE,{xaxis:{title:'Crude rate'},yaxis:{title:'Standardised rate'},shapes:[{type:'line',x0:700,y0:700,x1:1900,y1:1900,line:{dash:'dot',color:C.muted}}]}),CONFIG)}yearEl.addEventListener('change',render);metricEl.addEventListener('change',render);render();
 const rows=metro(DATA.regional_standardised);const names=[...new Set(rows.map(d=>d.region_name))];const years=[...new Set(rows.map(d=>d.study_year))];Plotly.newPlot('regions-heat',[{z:names.map(n=>years.map(y=>rows.find(d=>d.region_name===n&&+d.study_year===+y)?.standardised_rate_per_100000)),x:years,y:names,type:'heatmap',colorscale:colourScale(),colorbar:{title:'per 100,000'}}],merge(BASE,{margin:{l:190,r:35,t:10,b:45}}),CONFIG);Plotly.newPlot('regions-trends',names.map(n=>{const x=rows.filter(d=>d.region_name===n);return{x:x.map(d=>d.study_year),y:x.map(d=>d.standardised_rate_per_100000),name:n,type:'scatter',mode:'lines',line:{width:1.7}}}),merge(BASE,{yaxis:{title:'Standardised rate per 100,000'},hovermode:'x unified',legend:{orientation:'h',y:-.35,font:{size:10}}}),CONFIG)
}
function maps(){const y=document.getElementById('map-year'),m=document.getElementById('map-metric'),s=document.getElementById('map-scale'),c=document.getElementById('compare-year');function render(){drawMap('map-primary',+y.value,m.value,s.value==='common');drawRank('map-rank',+y.value,m.value);drawMap('map-compare',+c.value,m.value,true)}[y,m,s,c].forEach(el=>el.addEventListener('change',render));render()}
function substances(){
 const rows=DATA.substances,names=[...new Set(rows.map(d=>d.atc_name))],metric=document.getElementById('substance-metric');
 const defs={boxes:['Reimbursed boxes','boxes'],beneficiaries:['Beneficiaries','beneficiaries'],expenditure:['Reimbursed expenditure (€)','reimbursed_expenditure_eur']};
 function render(){
  const [label,key]=defs[metric.value];
  const traces=names.map((name,i)=>{const r=rows.filter(d=>d.atc_name===name);return{x:r.map(d=>d.year),y:r.map(d=>d[key]),name,type:'scatter',mode:'lines+markers',line:{width:2.5,color:[C.blue,C.orange,C.teal,C.purple][i]}}});
  Plotly.newPlot('substance-level',traces,merge(BASE,{yaxis:{title:label},hovermode:'x unified'}),CONFIG);
  const totals={};rows.forEach(d=>totals[d.year]=(totals[d.year]||0)+(+d[key]||0));
  const shares=names.map((name,i)=>{const r=rows.filter(d=>d.atc_name===name);return{x:r.map(d=>d.year),y:r.map(d=>100*d[key]/totals[d.year]),name,type:'bar',marker:{color:[C.blue,C.orange,C.teal,C.purple][i]}}});
  Plotly.newPlot('substance-share',shares,merge(BASE,{barmode:'stack',yaxis:{title:'Share (%)',range:[0,100]},hovermode:'x unified'}),CONFIG);
  const firstYear=Math.min(...rows.map(d=>d.year));
  const indexed=names.map((name,i)=>{const r=rows.filter(d=>d.atc_name===name),base=r.find(d=>d.year===firstYear)?.[key];return{x:r.map(d=>d.year),y:r.map(d=>base?100*d[key]/base:null),name,type:'scatter',mode:'lines+markers',line:{width:2,color:[C.blue,C.orange,C.teal,C.purple][i]}}});
  Plotly.newPlot('substance-index',indexed,merge(BASE,{yaxis:{title:`Index (${firstYear} = 100)`},hovermode:'x unified'}),CONFIG);
  document.getElementById('substance-table').innerHTML=table(rows,['year','atc_name',key]);
 }
 metric.addEventListener('change',render);render();
}
function demographics(){
 const rows=DATA.demographics.filter(d=>d.demographic_scope==='age_sex'),years=[...new Set(rows.map(d=>d.study_year))],ages=[...new Set(rows.map(d=>d.age_group))];
 ['Female','Male'].forEach((sex,i)=>{const s=rows.filter(d=>d.sex===sex);Plotly.newPlot(i?'demo-heat-m':'demo-heat-f',[{z:ages.map(a=>years.map(y=>s.find(d=>d.age_group===a&&+d.study_year===+y)?.beneficiary_rate_per_100000)),x:years,y:ages,type:'heatmap',colorscale:colourScale(),colorbar:{title:'per 100,000'},hovertemplate:'%{y}<br>%{x}: %{z:,.1f}<extra></extra>'}],merge(BASE,{margin:{l:110,r:35,t:10,b:45}}),CONFIG)});
 const age=document.getElementById('demo-age');ages.forEach(a=>age.add(new Option(a,a)));function render(){const r=rows.filter(d=>d.age_group===age.value);Plotly.newPlot('demo-trends',['Female','Male'].map((sex,i)=>{const s=r.filter(d=>d.sex===sex);return{x:s.map(d=>d.study_year),y:s.map(d=>d.beneficiary_rate_per_100000),name:sex,type:'scatter',mode:'lines+markers',line:{width:3,color:i?C.navy:C.teal}}}),merge(BASE,{yaxis:{title:'Rate per 100,000'},hovermode:'x unified'}),CONFIG)}age.addEventListener('change',render);render();
}
function profiles(){
 const select=document.getElementById('profile-region');
 const regions=[...new Map(metro(DATA.regional_standardised).map(d=>[String(d.region_code),d.region_name])).entries()];
 regions.forEach(([c,n])=>select.add(new Option(n,c)));
 function render(){
  const code=select.value,s=DATA.regional_standardised.filter(d=>String(d.region_code)===code),a=DATA.regional_annual.filter(d=>String(d.region_code)===code),latest=s.find(d=>+d.study_year===2025);
  setKpi('p-rate',fmtRate(latest.standardised_rate_per_100000),'standardised per 100,000');setKpi('p-crude',fmtRate(latest.crude_rate_per_100000),'crude per 100,000');setKpi('p-beneficiaries',fmtInt(a.find(d=>+d.study_year===2025).beneficiaries),'in 2025');
  const median=s.map(d=>{const x=metro(DATA.regional_standardised).filter(z=>+z.study_year===+d.study_year).map(z=>z.standardised_rate_per_100000).sort((a,b)=>a-b);return x[Math.floor(x.length/2)]});
  Plotly.newPlot('profile-trend',[{x:s.map(d=>d.study_year),y:s.map(d=>d.standardised_rate_per_100000),name:'Selected region',mode:'lines+markers',line:{color:C.teal,width:3}},{x:s.map(d=>d.study_year),y:median,name:'Metropolitan median',mode:'lines',line:{color:C.muted,width:2,dash:'dash'}}],merge(BASE,{yaxis:{title:'Standardised rate per 100,000'}}),CONFIG);
  const ages=['0','20','60'],sexes=[['1','Male'],['2','Female']];
  const traces=sexes.map(([sc,label],i)=>{const r=DATA.regional_age_sex.filter(d=>String(d.region_code)===code&&String(d.sex_code)===sc&&+d.study_year===2025);return{x:ages.map(ac=>r.find(d=>String(d.age_code)===ac)?.beneficiary_rate_per_100000),y:['0–19','20–59','60+'],name:label,type:'bar',orientation:'h',marker:{color:i?C.teal:C.navy},error_x:{type:'data',symmetric:false,array:ages.map(ac=>{const d=r.find(x=>String(x.age_code)===ac);return d?d.beneficiary_rate_upper_per_100000-d.beneficiary_rate_per_100000:0}),arrayminus:ages.map(ac=>{const d=r.find(x=>String(x.age_code)===ac);return d?d.beneficiary_rate_per_100000-d.beneficiary_rate_lower_per_100000:0})}}});
  Plotly.newPlot('profile-age',traces,merge(BASE,{barmode:'group',xaxis:{title:'Rate per 100,000'}}),CONFIG);
 }
 select.addEventListener('change',render);render();
}
function overseas(){const r=DATA.overseas_audit;Plotly.newPlot('overseas-rate',[{x:r.map(d=>d.study_year),y:r.map(d=>d.beneficiary_rate_per_100000),name:'Overseas aggregate',mode:'lines+markers',line:{color:C.purple,width:3}},{x:r.map(d=>d.study_year),y:r.map(d=>d.metropolitan_median_crude_rate),name:'Metropolitan median',mode:'lines+markers',line:{color:C.teal,width:2,dash:'dash'}}],merge(BASE,{yaxis:{title:'Crude rate per 100,000'}}),CONFIG);Plotly.newPlot('overseas-ratio',[{x:r.map(d=>d.study_year),y:r.map(d=>d.overseas_to_metro_median_rate_ratio),type:'bar',marker:{color:C.purple},text:r.map(d=>d.overseas_to_metro_median_rate_ratio.toFixed(2)+'×'),textposition:'outside'}],merge(BASE,{yaxis:{title:'Ratio to metropolitan median'},showlegend:false}),CONFIG);document.getElementById('overseas-table').innerHTML=table(r,['study_year','beneficiaries','beneficiary_rate_per_100000','metropolitan_median_crude_rate','overseas_to_metro_median_rate_ratio']);}
function explorer(){const dataset=document.getElementById('explorer-dataset'),year=document.getElementById('explorer-year'),search=document.getElementById('explorer-search');let current=[];function render(){const rows=DATA[dataset.value]||[],q=search.value.toLowerCase();current=rows.filter(d=>(year.value==='all'||String(d.study_year??d.year)===year.value)&&(!q||JSON.stringify(d).toLowerCase().includes(q)));const cols=[...new Set(current.slice(0,100).flatMap(Object.keys))].filter(c=>!c.includes('source_file')&&!c.includes('denominator_source')).slice(0,12);document.getElementById('explorer-count').textContent=`${fmtInt(current.length)} records`;document.getElementById('explorer-table').innerHTML=current.length?table(current,cols):'<p class="empty">No records match the current filters.</p>';}function years(){const vals=[...new Set((DATA[dataset.value]||[]).map(d=>d.study_year??d.year).filter(Boolean))].sort();year.innerHTML='<option value="all">All years</option>'+vals.map(v=>`<option>${v}</option>`).join('');render()}dataset.addEventListener('change',years);year.addEventListener('change',render);search.addEventListener('input',render);document.getElementById('explorer-download').addEventListener('click',()=>{if(!current.length)return;const cols=[...new Set(current.flatMap(Object.keys))],esc=v=>`"${String(v??'').replaceAll('"','""')}"`,csv=[cols.join(','),...current.map(r=>cols.map(c=>esc(r[c])).join(','))].join('\n'),a=document.createElement('a');a.href=URL.createObjectURL(new Blob([csv],{type:'text/csv'}));a.download=`glp1-${dataset.value}.csv`;a.click();URL.revokeObjectURL(a.href)});years();}
function humanLabel(key){const labels={year:'Year',study_year:'Year',atc_name:'Active substance',beneficiaries:'Beneficiaries',beneficiaries_per_100000:'Rate per 100,000',beneficiary_rate_per_100000:'Beneficiary rate per 100,000',standardised_rate_per_100000:'Standardised rate per 100,000',crude_rate_per_100000:'Crude rate per 100,000',annual_beneficiary_percentage_change:'Annual change (%)',reimbursed_expenditure_eur:'Reimbursed expenditure (€)',metropolitan_median_crude_rate:'Metropolitan median crude rate',overseas_to_metro_median_rate_ratio:'Ratio to metropolitan median',atc_code:'ATC code'};if(labels[key])return labels[key];return key.replaceAll('_',' ').replace(/\beur\b/gi,'€').replace(/\batc\b/gi,'ATC').replace(/^./,x=>x.toUpperCase())}
function table(rows,cols){return `<table><thead><tr>${cols.map(c=>`<th>${humanLabel(c)}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${cols.map(c=>`<td>${r[c]==null?'—':typeof r[c]==='number'?new Intl.NumberFormat('en-GB',{maximumFractionDigits:1}).format(r[c]):r[c]}</td>`).join('')}</tr>`).join('')}</tbody></table>`}
const FIGURE_CAPTIONS={
 'overview-national':'Lines show annual beneficiaries (navy; left axis) and beneficiaries per 100,000 residents (teal; right axis). Points are calendar-year observations. Sources: Open Medic and INSEE.',
 'overview-composition':'Stacked areas show each active substance’s percentage of all reimbursed boxes in a calendar year; the vertical total is 100%. Source: Open Medic.',
 'overview-map':'Colour encodes the age–sex-standardised beneficiary rate per 100,000 residents for the selected year. White lines delimit metropolitan regions; PACA and Corse share one estimate. Sources: Open Medic, INSEE and Etalab/IGN ADMIN EXPRESS.',
 'overview-rank':'Horizontal bars rank metropolitan analytical groupings by the selected year’s standardised rate per 100,000. Colour reinforces the rate magnitude. Sources: Open Medic and INSEE.',
 'national-level':'The line and points show the selected annual national measure; the vertical axis gives either beneficiaries or the rate per 100,000. Sources: Open Medic and INSEE.',
 'national-index':'The line shows the selected measure relative to its 2020 value, fixed at 100; values above 100 indicate growth from baseline. Sources: Open Medic and INSEE.',
 'national-change':'Bars show percentage change from the preceding calendar year. Bar labels give exact displayed percentages; colour indicates relative magnitude within the series. Sources: Open Medic and INSEE.',
 'substance-level':'Lines and points show the selected annual measure for each active substance; colours identify substances consistently across this page. Source: Open Medic.',
 'substance-share':'Stacked bars show each substance’s percentage contribution to the selected annual total; each bar sums to 100%. Source: Open Medic.',
 'substance-index':'Each line compares a substance with its own 2019 value, fixed at 100; indices compare growth, not absolute volume. Source: Open Medic.',
 'demo-heat-f':'Cell colour represents the female beneficiary rate per 100,000 for each age group and year. This panel uses its own colour scale. Sources: Open Medic and INSEE.',
 'demo-heat-m':'Cell colour represents the male beneficiary rate per 100,000 for each age group and year. This panel uses its own colour scale. Sources: Open Medic and INSEE.',
 'demo-trends':'Lines compare female and male beneficiary rates per 100,000 for the selected age group across calendar years. Sources: Open Medic and INSEE.',
 'regions-rank':'Horizontal bars rank metropolitan analytical groupings by the selected crude or standardised rate. Colour reinforces magnitude. Sources: Open Medic and INSEE.',
 'regions-adjustment':'Each point is one metropolitan grouping. The horizontal axis is the crude rate and the vertical axis the age–sex-standardised rate; the dotted diagonal indicates equality. Sources: Open Medic and INSEE.',
 'regions-heat':'Cell colour represents the age–sex-standardised rate per 100,000 for one metropolitan grouping and year. A common scale permits temporal and geographic comparison. Sources: Open Medic and INSEE.',
 'regions-trends':'Each coloured line represents one metropolitan analytical grouping; position on the vertical axis gives its standardised rate per 100,000. Sources: Open Medic and INSEE.',
 'map-primary':'Colour encodes the selected rate for the primary year. White boundaries delimit metropolitan geometries; hover text reports beneficiaries and both rate definitions. Sources: Open Medic, INSEE and Etalab/IGN ADMIN EXPRESS.',
 'map-rank':'Bars rank the same year and measure shown in the primary map, linking geographic colour patterns to exact ordering. Sources: Open Medic and INSEE.',
 'map-compare':'Colour encodes the selected rate for the comparison year using the common 2020–2025 scale. PACA and Corse share one analytical estimate. Sources: Open Medic, INSEE and Etalab/IGN ADMIN EXPRESS.',
 'profile-trend':'The solid line shows the selected region’s standardised rate; the dashed line shows the median across metropolitan analytical groupings. Sources: Open Medic and INSEE.',
 'profile-age':'Grouped horizontal bars compare male and female rates by age in 2025. Whiskers, when present, are disclosure-control bounds rather than confidence intervals. Sources: Open Medic and INSEE.',
 'overseas-rate':'The solid line shows the combined overseas crude rate; the dashed line shows the median crude rate across metropolitan groupings. Individual overseas territories cannot be separated. Sources: Open Medic and INSEE.',
 'overseas-ratio':'Bars show the combined overseas crude rate divided by the metropolitan median; 1 would indicate equality. Labels report the displayed ratio. Sources: Open Medic and INSEE.'
};
function addFigureCaptions(){for(const [id,text] of Object.entries(FIGURE_CAPTIONS)){const plot=document.getElementById(id);if(!plot||plot.nextElementSibling?.classList.contains('chart-caption'))continue;const caption=document.createElement('p');caption.className='chart-caption';caption.innerHTML=`<strong>Reading guide.</strong> ${text}`;plot.insertAdjacentElement('afterend',caption)}}
document.addEventListener('DOMContentLoaded',load);
