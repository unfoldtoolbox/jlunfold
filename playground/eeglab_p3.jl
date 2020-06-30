using unfold, DataFrames
using StatsModels
using Plots,StatsPlots
using Statistics
using DataFramesMeta

plotlyjs()
include("../test/debug_readEEGlab.jl")
include("dataset-CORE_helper.jl")
##
# Single Subject

sub = 2
filename = "C:/Users/behinger/Downloads/P3_clean/$(sub)_P3_shifted_ds_reref_ucbip_hpfilt_ica_weighted.set"
filename = "C:/Users/behinger/Downloads/1_P3_shifted_ds_reref_ucbip_hpfilt_ica_corr_cbip_elist.set"
data,srate,evts_df,chanlocs_df = import_eeglab(filename)
evts= parse_trigger_p3(evts_df)

## Epoch & Mass Univariate
evts_stim = filter(x->x.eventtype=="stimulus",evts)
data_e,times = unfold.epoch(data=data,tbl=evts_stim,τ=(-0.3,1),sfreq=srate)

##
f = @formula 0~0+stimtype
um,res = fit(UnfoldLinearModel,f, evts_stim,data_e,times)
@df filter(x->x.channel==findfirst(chanlocs_df.labels.=="Cz"),res) plot(:colname_basis,:estimate,group=(:term))
#```
##

Xstim = designmatrix(UnfoldLinearModel,@formula(0~0+stimtype),filter(x->(x.eventtype=="stimulus"),evts),firbasis((-0.3,1),srate,"stimulus"))

evts.rt_s = evts.rt .- mean(filter(!isnan,evts.rt))
evts.rt_s = evts.rt_s ./ std(filter(!isnan,evts.rt_s))
Xbutt = designmatrix(UnfoldLinearModel,@formula(0~1+correct+rt_s),filter(x->(x.eventtype=="button")&(typeof(x.target)==String),evts),firbasis((-0.5,0.4),srate,"button"))

#,contrasts=Dict(:rt_s=>EffectsCoding,:correct=>EffectsCoding))

@time m = unfoldfit(UnfoldLinearModel,Xstim+Xbutt,data)


res = condense_long(m)
res.times = res.colname_basis



@df filter(x->(x.basisname=="stimulus")&(x.term!="correct: NaN")&(x.channel==findfirst(chanlocs_df.labels.=="Cz")),res) plot(:times,:estimate,group=(:term))

@df filter(x->(x.basisname=="button")&(x.term!="correct: NaN")&(x.channel==findfirst(chanlocs_df.labels.=="Cz")),res) plot(:times,:estimate,group=(:term))


## All Subjects

resAll = DataFrame()


for sub in 1:5
    if sub == 17
        continue
    end
    println("subject $sub")

    # load data
    filename = "C:/Users/behinger/Downloads/p3_clean/$(sub)_P3_shifted_ds_reref_ucbip_hpfilt_ica_weighted.set"
    data,srate,evts_df,chanlocs_df = import_eeglab(filename)
    
    evts= parse_trigger_p3(evts_df)
    evts = @where(evts, .!:invalidresponse)
    # Mass Univariate
    f_stim = @formula 0~1+trialtype
    f_butt = @formula 0~1+trialtype+answer
    contrast = Dict(:trialtype => DummyCoding(base="distractor"),:answer=>DummyCoding(base="distractor"))
    evts_stim = filter(x->x.eventtype=="stimulus",evts)
    data_e,times = unfold.epoch(data=data,tbl=evts_stim,τ=(-0.8,1.3),sfreq=srate)
    um,res = fit(UnfoldLinearModel,f_stim, evts_stim,data_e,times,contrasts=contrast)
    res.basisname .= "stimulus"
    
    evts_butt = @where(evts,:eventtype.=="button",.!isnan.(:correct))
    data_e,times = unfold.epoch(data=data,tbl=evts_butt,τ=(-0.5,0.4),sfreq=srate)
    um,res_tmp = fit(UnfoldLinearModel,f_butt, evts_butt,data_e,times,contrasts=contrast)
    res_tmp.basisname .= "button"

    append!(res,res_tmp)
    res.group .="no-dc"

    # Deconv
    Xstim = designmatrix(UnfoldLinearModel,f_stim,filter(x->(x.eventtype=="stimulus"),evts),firbasis((-0.8,1.3),srate,"stimulus"),contrasts=contrast)
    Xbutt = designmatrix(UnfoldLinearModel,f_butt, filter(x->(x.eventtype=="button")&(typeof(x.target)==String),evts),firbasis((-0.5,0.4),srate,"button"),contrasts=contrast)

    m = unfoldfit(UnfoldLinearModel,Xstim+Xbutt,data)
    res_dc = condense_long(m)
    res_dc.group .="dc"
    append!(res,res_dc)
    res[:,:subject] .= sub
    append!(resAll,res)
end

##



## Plotting

x = @linq resAll |>
    where(:basisname.=="stimulus", :channel .==findfirst(chanlocs_df.labels.=="Cz"))|>
    groupby([:term,:group,:colname_basis,:channel,:basisname]) |>
    based_on(estimate = mean(:estimate),sd = std(:estimate))


    @df x plot(:colname_basis,:estimate,linecolor=[:red :red :blue :blue],linestyle=[:solid :dot :solid :dot],group=(:group,:term),legend=:topleft)
    #,yerror=:sd)
    #@df x plot(:colname_basis,:estimate,linecolor=:auto,group=(:term,:group),legend=:outerbottom)

    #,yerror=:sd)

