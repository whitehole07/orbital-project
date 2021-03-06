function varargout = ComputeDv(dep, ga, arr, dep_id, ga_id, ga_mu, arr_id, body_mu, ga_Rlim)
%ComputeDv: computation of the total delta velocity needed to perform an
%interplanetary transfer, including a fly-by
% 
% PROTOTYPE: 
% varargout = ComputeDv(dep, ga, arr, dep_id, ga_id, ga_mu, arr_id, body_mu, ga_Rlim)
% 
% INPUT:
% dep      [1x1] Time of departure                                       [T]
% ga       [1x1] Time of gravity assist                                  [T]
% arr      [1x1] Time of arrival                                         [T]
% dep_id   [1x1] Identity code of the departure planet                   [-]
% ga_id    [1x1] Identity code of the gravity assist planet              [-]
% ga_mu    [1x1] Planetary constant of the gravity assist planet         [km^3/s^2]
% arr_id   [1x1] Identity code of the arrival planet                     [-]
% body_mu  [1x1] Planetary constant of the central body (Sun)            [km^3/s^2]
% ga_Rlim  [1x1] Minimum altitude for safe flyby                         [km]
%
% OUTPUT:
%
%     varargout{1} = Dv;                                        Total Dv for interplanetary transfer [km/s]?     
%     if nargout > 1; varargout{2} = [vInfMinus vInfPlus]       Hyperbolas velocities                [km/s]?
%     if nargout > 2; varargout{3} = [v1l' v2l']                Lambert velocities                   [km/s]?
%     if nargout > 3; varargout{4} = [Dv1 Dv2 Dvfb Dvga]        Detailed Dvs                         [km/s]?
%     if nargout > 4; varargout{5} = turnAngle                  Turn Angle                           [rad]?
%  
% CONTRIBUTORS:
% Daniele Agamennone, Davide Gianmoena
%
% VERSIONS
% 2021-10-20: First version
%
    % Don't consider Rlim in this case
    if nargin < 9; ga_Rlim = 0; end

    % Initial state
    ti = dep * 86400; % Total seconds
    % passed since January 1, 2000
    [kep_i, ~] = uplanet(dep, dep_id);
    [ri, vi] = KeplerianToCartesian(kep_i, body_mu);

    % Powered Gravity Assist state
    tga = ga * 86400; % Total seconds
    % passed since January 1, 2000
    [kep_j, ~] = uplanet(ga, ga_id);
    [rga, vga] = KeplerianToCartesian(kep_j, body_mu);

    try
        % Lambert
        [Dv1, v1l] = LambertTransfer(ri, rga, vi, vga, tga - ti, body_mu, 0);  % Last input is verbosity

        % Useful variables
        Dv1 = Dv1(1); VMinus = v1l(2, :)';
    catch
        varargout = cell(1, nargout);
        for n = 1:nargout; varargout{n} = NaN; end
        return
    end

    % Final state
    tf = arr * 86400; % Total seconds passed since January 1, 2000
    [kep_k, ~] = uplanet(arr, arr_id);
    [rf, vf] = KeplerianToCartesian(kep_k, body_mu);
    
    try
        % Lambert
        [Dv2, v2l] = LambertTransfer(rga, rf, vga, vf, tf - tga, body_mu, 0);  % Last input is verbosity

        % Useful variables
        Dv2 = Dv2(2); VPlus = v2l(1, :)';

        % From Heliocentric to Planetocentric
        Vp = vga;                                 % Gravity assist planet velocity
        vInfMinus = VMinus - Vp;                  % Minus Inf planetocentric velocity
        vInfPlus = VPlus - Vp;                    % Plus Inf planetocentric velocity

        % Powered Gravity Assist
        [turnAngle, ~, Dvfb, Dvga, ~, ~, ~, ~, ~] = PoweredGravityAssist(vInfMinus, vInfPlus, ga_mu, ga_Rlim);
    catch
        varargout = cell(1, nargout);
        for n = 1:nargout; varargout{n} = NaN; end
        return
    end
    
    % Updating output variables
    Dv = Dv1 + Dv2 + Dvga;

    % Output arguments
    varargout{1} = Dv;
    if nargout > 1; varargout{2} = [vInfMinus vInfPlus]; end       % Hyperbolas velocities
    if nargout > 2; varargout{3} = [v1l' v2l']; end                % Lambert velocities
    if nargout > 3; varargout{4} = [Dv1 Dv2 Dvfb Dvga]; end        % Detailed Dvs
    if nargout > 4; varargout{5} = turnAngle; end                  % Turn Angle
end

